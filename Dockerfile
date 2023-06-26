FROM ubuntu:22.04

ENV DEBIAN_FRONTEND="noninteractive"
ENV JAVA_VERSION="11"
ENV ANDROID_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip"
ENV ANDROID_VERSION="33"
ENV ANDROID_BUILD_TOOLS_VERSION="33.0.2"
ENV ANDROID_ARCHITECTURE="x86_64"
ENV ANDROID_SDK_ROOT="/home/dev/android-sdk"
ENV ANDROID_EMULATOR_IMAGE="system-images;android-33;google_apis_playstore;arm64-v8a"
ENV FLUTTER_CHANNEL="beta"
ENV FLUTTER_VERSION="3.12.0"
ENV GRADLE_VERSION="7.5"
ENV GRADLE_USER_HOME="/home/dev/gradle"
ENV GRADLE_URL="https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip"
ENV FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/$FLUTTER_CHANNEL/linux/flutter_linux_$FLUTTER_VERSION-$FLUTTER_CHANNEL.tar.xz"
ENV FLUTTER_ROOT="/home/dev/flutter"
ENV PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/platforms:$FLUTTER_ROOT/bin:$GRADLE_USER_HOME/bin:$PATH"

# Install the necessary dependencies.
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    apt-transport-https \
    bash \
    curl \
    clang \
    coreutils \
    cmake \
    git \
    gpg \
    gpg-agent \
    libpulse0 \
    libxcomposite1 \
    libgl1-mesa-glx \
    libglvnd0 \
    libgtk-3-dev \
    liblzma-dev \
    ninja-build \
    pkg-config \
    sed \
    ssh \
    sudo \
    unzip \
    usbutils \
    wget \
    xz-utils \    
    xauth \
    x11-xserver-utils \
    openjdk-$JAVA_VERSION-jdk \
  && rm -rf /var/lib/{apt,dpkg,cache,log}

# Install DEV tools
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \ 
    && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list
RUN apt-get update && apt-get -y install google-chrome-stable
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
RUN install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
RUN sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
RUN rm -f packages.microsoft.gpg
RUN apt update && apt install -y code

# Non root user
RUN useradd -rm -d /home/dev -s /bin/bash -g root -G sudo -u 1000 -p "dev" dev
RUN echo "dev ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/dev
USER dev
WORKDIR /home/dev
# RUN sudo chown -R dev /opt/flutter 

# Install Gradle.
RUN curl -L $GRADLE_URL -o gradle-$GRADLE_VERSION-bin.zip \
  && unzip gradle-$GRADLE_VERSION-bin.zip \
  && mv gradle-$GRADLE_VERSION $GRADLE_USER_HOME \
  && rm gradle-$GRADLE_VERSION-bin.zip

# Install the Android SDK.
RUN mkdir /home/dev/.android \
  && touch /home/dev/.android/repositories.cfg \
  && mkdir -p $ANDROID_SDK_ROOT \
  && curl -o android_tools.zip $ANDROID_TOOLS_URL \
  && unzip -qq -d "$ANDROID_SDK_ROOT" android_tools.zip \
  && rm android_tools.zip \
  && mv $ANDROID_SDK_ROOT/cmdline-tools $ANDROID_SDK_ROOT/latest \
  && mkdir -p $ANDROID_SDK_ROOT/cmdline-tools \
  && mv $ANDROID_SDK_ROOT/latest $ANDROID_SDK_ROOT/cmdline-tools/latest \
  && yes "y" | sdkmanager "build-tools;$ANDROID_BUILD_TOOLS_VERSION" \
  && yes "y" | sdkmanager "platforms;android-$ANDROID_VERSION" \
  && yes "y" | sdkmanager "platform-tools" \
  && yes "y" | sdkmanager --install "$ANDROID_EMULATOR_IMAGE"

# Install Flutter.
RUN curl -o flutter.tar.xz $FLUTTER_URL \
  && mkdir -p $FLUTTER_ROOT \
  && tar xf flutter.tar.xz -C /home/dev/ \
  && rm flutter.tar.xz \
  && git config --global --add safe.directory /home/dev/flutter \
  && flutter config --no-analytics \
  && flutter precache \
  && yes "y" | flutter doctor --android-licenses \
  && flutter doctor \
  && flutter update-packages
