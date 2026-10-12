{
  lib,
  stdenv,
  fetchFromGitHub,
  libbsd,
  pkg-config,
  coreutils,
  iproute2,
  which,
  gawk,
  gnused,
  kmod,
  dhcpcd,
  ethtool,
  atf,
  kyua,
  useBusybox ? false,
  busybox,
  useBatctl ? true,
  batctl,
  useWireless ? true,
  wpa_supplicant,
  wirelesstools,
  useWireguard ? true,
  wireguard-tools,
}:

stdenv.mkDerivation (final: {
  pname = "ifupdown-ng";
  version = "0.13.0";

  src = fetchFromGitHub {
    owner = "ifupdown-ng";
    repo = "ifupdown-ng";
    tag = "ifupdown-ng-${final.version}";
    hash = "sha256-+M8c59LjJlO1Vdl+Lo5EXjMEaHWemGWvBsDw/MaY/IE=";
  };

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ libbsd ];

  postPatch = ''
    # replace _PATH_STDPATH with a path that includes nix store locations.
    # ifupdown-ng sets PATH to this value before running executor scripts.
    substituteInPlace libifupdown/lifecycle.c \
      --replace-fail '_PATH_STDPATH' '"${
        lib.makeBinPath (
          [
            iproute2
            coreutils
            dhcpcd
            which
            gawk
            gnused
            kmod
            ethtool
          ]
          ++ lib.optional useBusybox busybox
          ++ lib.optional useBatctl batctl
          ++ lib.optionals useWireless [
            wpa_supplicant
            wirelesstools
          ]
          ++ lib.optional useWireguard wireguard-tools
        )
      }"'

    # remove hardcoded FHS paths from executor scripts so they use PATH lookup.
    # Replace full path for dhcpcd to make autodetect work.
    substituteInPlace executors/linux/dhcp \
      --replace-fail '/sbin/dhcpcd' '${lib.getExe dhcpcd}' \
      --replace-fail '/usr/sbin/dhclient' 'dhclient' \
      --replace-fail '/sbin/udhcpc' 'udhcpc'
    substituteInPlace executors/linux/vrf \
      --replace-fail '/sbin/ip' 'ip'
    substituteInPlace executors/linux/wifi \
      --replace-fail '/sbin/wpa_passphrase' 'wpa_passphrase' \
      --replace-fail '/sbin/wpa_supplicant' 'wpa_supplicant' \
      --replace-fail '/usr/sbin/iwconfig' 'iwconfig'

    # the following is required for the test suite to run.
    substituteInPlace executors/linux/batman \
      --replace-fail 'which' 'command -v'
    substituteInPlace executors/linux/bridge \
      --replace-fail 'which' 'command -v'
    substituteInPlace executors/linux/gre \
      --replace-fail 'which ip' 'command -v ip || echo "none"'

    substituteInPlace tests/linux/dhcp_test \
      --replace-fail '/sbin/dhcpcd' 'dhcpcd' \
      --replace-fail '/usr/sbin/dhclient' 'dhclient' \
      --replace-fail '/sbin/udhcpc' 'udhcpc'

    patchShebangs --build tests
  ''
  # The Makefile hardcodes -static; remove it to build dynamically.
  + lib.optionalString (!stdenv.hostPlatform.isStatic) ''
    substituteInPlace Makefile \
      --replace-fail ' -static ' ' '
  '';

  makeFlags = [
    "SBINDIR=/bin"
    "EXECUTOR_PATH=/libexec/ifupdown-ng"
  ];

  installFlags = [
    "DESTDIR=${placeholder "out"}"
  ];

  doCheck = true;

  checkInputs = [
    atf
    kyua
  ];

  meta = {
    description = "Next-generation network interface configuration tool";
    longDescription = ''
      ifupdown-ng is a network device manager that is largely compatible
      with Debian ifupdown, BusyBox ifupdown, and other implementations.
      It is used by Alpine Linux as its network management solution.
    '';
    homepage = "https://github.com/ifupdown-ng/ifupdown-ng";
    license = lib.licenses.isc;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ aanderse ];
  };
})
