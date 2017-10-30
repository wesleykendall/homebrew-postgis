class Postgresql < Formula
  desc "Object-relational database system"
  homepage "https://www.postgresql.org/"
  url "https://ftp.postgresql.org/pub/source/v9.6.5/postgresql-9.6.5.tar.bz2"
  sha256 "06da12a7e3dddeb803962af8309fa06da9d6989f49e22865335f0a14bad0744c"
  head "https://github.com/postgres/postgres.git"

  bottle do
    sha256 "49fdadf8a3c6807f464248a0d150bb216dbc38648bd6278321f98e71c8cc043f" => :high_sierra
    sha256 "d1cf9ba381f1a92fc4c5df2e861d40d05993ac39c8cd222dd72cd3c820af8cb4" => :sierra
    sha256 "3b97a7f8b60b80afbcb91eeed7a69c72227b106cc3221566268511525c3322f3" => :el_capitan
    sha256 "8a74b1afc029179dd1ff653e5a5016476ce0fd6e6260ca2a067b1de2043d0265" => :yosemite
  end

  option "without-perl", "Build without Perl support"
  option "without-tcl", "Build without Tcl support"
  option "with-dtrace", "Build with DTrace support"
  option "with-python", "Enable PL/Python2"
  option "with-python3", "Enable PL/Python3 (incompatible with --with-python)"

  deprecated_option "no-perl" => "without-perl"
  deprecated_option "no-tcl" => "without-tcl"
  deprecated_option "enable-dtrace" => "with-dtrace"

  depends_on "openssl"
  depends_on "readline"

  depends_on :python => :optional
  depends_on :python3 => :optional

  conflicts_with "postgres-xc",
    :because => "postgresql and postgres-xc install the same binaries."

  fails_with :clang do
    build 211
    cause "Miscompilation resulting in segfault on queries"
  end

  def install
    # avoid adding the SDK library directory to the linker search path
    ENV["XML2_CONFIG"] = "xml2-config --exec-prefix=/usr"

    ENV.prepend "LDFLAGS", "-L#{Formula["openssl"].opt_lib} -L#{Formula["readline"].opt_lib}"
    ENV.prepend "CPPFLAGS", "-I#{Formula["openssl"].opt_include} -I#{Formula["readline"].opt_include}"

    args = %W[
      --disable-debug
      --prefix=#{prefix}
      --datadir=#{HOMEBREW_PREFIX}/share/postgresql
      --libdir=#{HOMEBREW_PREFIX}/lib
      --sysconfdir=#{etc}
      --docdir=#{doc}
      --enable-thread-safety
      --with-bonjour
      --with-gssapi
      --with-ldap
      --with-openssl
      --with-pam
      --with-libxml
      --with-libxslt
    ]

    args << "--with-perl" if build.with? "perl"

    which_python = nil
    if build.with?("python") && build.with?("python3")
      odie "Cannot provide both --with-python and --with-python3"
    elsif build.with?("python") || build.with?("python3")
      args << "--with-python"
      which_python = which(build.with?("python") ? "python" : "python3")
    end
    ENV["PYTHON"] = which_python

    # The CLT is required to build Tcl support on 10.7 and 10.8 because
    # tclConfig.sh is not part of the SDK
    if build.with?("tcl") && (MacOS.version >= :mavericks || MacOS::CLT.installed?)
      args << "--with-tcl"

      if File.exist?("#{MacOS.sdk_path}/System/Library/Frameworks/Tcl.framework/tclConfig.sh")
        args << "--with-tclconfig=#{MacOS.sdk_path}/System/Library/Frameworks/Tcl.framework"
      end
    end

    args << "--enable-dtrace" if build.with? "dtrace"
    args << "--with-uuid=e2fs"

    system "./configure", *args
    system "make"
    system "make", "install-world", "datadir=#{pkgshare}",
                                    "libdir=#{lib}",
                                    "pkglibdir=#{lib}/postgresql"
  end

  def post_install
    (var/"log").mkpath
    (var/"postgres").mkpath
    unless File.exist? "#{var}/postgres/PG_VERSION"
      system "#{bin}/initdb", "#{var}/postgres"
    end
  end

  def caveats; <<-EOS.undent
    If builds of PostgreSQL 9 are failing and you have version 8.x installed,
    you may need to remove the previous version first. See:
      https://github.com/Homebrew/legacy-homebrew/issues/2510

    To migrate existing data from a previous major version (pre-9.0) of PostgreSQL, see:
      https://www.postgresql.org/docs/9.6/static/upgrading.html

    To migrate existing data from a previous minor version (9.0-9.5) of PostgreSQL, see:
      https://www.postgresql.org/docs/9.6/static/pgupgrade.html

      You will need your previous PostgreSQL installation from brew to perform `pg_upgrade`.
      Do not run `brew cleanup postgresql` until you have performed the migration.
    EOS
  end

  plist_options :manual => "pg_ctl -D #{HOMEBREW_PREFIX}/var/postgres start"

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>KeepAlive</key>
      <true/>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/postgres</string>
        <string>-D</string>
        <string>#{var}/postgres</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>WorkingDirectory</key>
      <string>#{HOMEBREW_PREFIX}</string>
      <key>StandardErrorPath</key>
      <string>#{var}/log/postgres.log</string>
    </dict>
    </plist>
    EOS
  end

  test do
    system "#{bin}/initdb", testpath/"test"
    assert_equal "#{HOMEBREW_PREFIX}/share/postgresql", shell_output("#{bin}/pg_config --sharedir").chomp
    assert_equal "#{HOMEBREW_PREFIX}/lib", shell_output("#{bin}/pg_config --libdir").chomp
    assert_equal "#{HOMEBREW_PREFIX}/lib/postgresql", shell_output("#{bin}/pg_config --pkglibdir").chomp
  end
end
