Name:           wsa-linux
Version:        2210.40000.7.0
Release:        1%{?dist}
Summary:        Windows Subsystem for Android (WSA) on Fedora Linux

License:        AGPLv3 and Apache-2.0
URL:            https://github.com/MustardChef/WSABuilds
Source0:        %{name}-%{version}.tar.gz

BuildArch:      x86_64
Requires:       qemu-kvm
Requires:       qemu-img
Requires:       android-tools
Requires:       e2fsprogs
Requires:       python3
Requires:       python3-tkinter
Requires:       pulseaudio-utils
Requires:       xdg-utils
Requires:       libnotify

%description
Windows Subsystem for Android (WSA) ported to Fedora Linux.
Includes prebuilt Android 12.1 (API 32) images with Google Play Store
(MindTheGapps), Magisk root solution, seamless desktop integration,
hardware-accelerated VirGL 3D graphics, and PipeWire/PulseAudio.

%prep
%autosetup

%build
# Nothing to compile, prebuilt binaries and scripts

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/opt/wsa-linux/bin
mkdir -p $RPM_BUILD_ROOT/opt/wsa-linux/images
mkdir -p $RPM_BUILD_ROOT/opt/wsa-linux/desktop
mkdir -p $RPM_BUILD_ROOT/opt/wsa-linux/systemd
mkdir -p $RPM_BUILD_ROOT%{_bindir}
mkdir -p $RPM_BUILD_ROOT%{_datadir}/applications
mkdir -p $RPM_BUILD_ROOT%{_userunitdir}
mkdir -p $RPM_BUILD_ROOT%{_udevrulesdir}

# Install executable scripts
install -m 0755 bin/wsa-runner.sh $RPM_BUILD_ROOT/opt/wsa-linux/bin/wsa-runner
install -m 0755 bin/wsa-client $RPM_BUILD_ROOT/opt/wsa-linux/bin/wsa-client
install -m 0755 bin/wsa-app $RPM_BUILD_ROOT/opt/wsa-linux/bin/wsa-app
install -m 0755 bin/wsa-sync-apps $RPM_BUILD_ROOT/opt/wsa-linux/bin/wsa-sync-apps
install -m 0755 bin/wsa-settings $RPM_BUILD_ROOT/opt/wsa-linux/bin/wsa-settings
install -m 0755 bin/wsa-uninstaller $RPM_BUILD_ROOT/opt/wsa-linux/bin/wsa-uninstaller

# Symlinks in /usr/bin
ln -sf /opt/wsa-linux/bin/wsa-runner $RPM_BUILD_ROOT%{_bindir}/wsa-runner
ln -sf /opt/wsa-linux/bin/wsa-client $RPM_BUILD_ROOT%{_bindir}/wsa-client
ln -sf /opt/wsa-linux/bin/wsa-app $RPM_BUILD_ROOT%{_bindir}/wsa-app
ln -sf /opt/wsa-linux/bin/wsa-sync-apps $RPM_BUILD_ROOT%{_bindir}/wsa-sync-apps
ln -sf /opt/wsa-linux/bin/wsa-settings $RPM_BUILD_ROOT%{_bindir}/wsa-settings
ln -sf /opt/wsa-linux/bin/wsa-uninstaller $RPM_BUILD_ROOT%{_bindir}/wsa-uninstaller

# Install desktop files
install -m 0644 desktop/wsa-settings.desktop $RPM_BUILD_ROOT%{_datadir}/applications/wsa-settings.desktop
install -m 0644 desktop/wsa-uri-handler.desktop $RPM_BUILD_ROOT%{_datadir}/applications/wsa-uri-handler.desktop

# Install systemd service
install -m 0644 systemd/wsa-linux.service $RPM_BUILD_ROOT%{_userunitdir}/wsa-linux.service

# Install udev rule for KVM
cat << 'EOF' > $RPM_BUILD_ROOT%{_udevrulesdir}/65-wsa-kvm.rules
KERNEL=="kvm", GROUP="kvm", MODE="0666"
EOF

# Copy images if available during packaging
if [ -d images ]; then
    cp -r images/* $RPM_BUILD_ROOT/opt/wsa-linux/images/
fi

%post
/usr/bin/udevadm control --reload-rules || :
/usr/bin/udevadm trigger --name-match=kvm || :
/usr/bin/update-desktop-database &> /dev/null || :

%postun
/usr/bin/update-desktop-database &> /dev/null || :

%files
/opt/wsa-linux
%{_bindir}/wsa-runner
%{_bindir}/wsa-client
%{_bindir}/wsa-app
%{_bindir}/wsa-sync-apps
%{_bindir}/wsa-settings
%{_bindir}/wsa-uninstaller
%{_datadir}/applications/wsa-settings.desktop
%{_datadir}/applications/wsa-uri-handler.desktop
%{_userunitdir}/wsa-linux.service
%{_udevrulesdir}/65-wsa-kvm.rules

%changelog
* Wed Oct 14 2026 MustardChef / LSA Contributors <support@wsabuilds.local> - 2210.40000.7.0-1
- Initial Fedora release converting WSA 2210.40000.7.0 with Magisk & MindTheGapps.
