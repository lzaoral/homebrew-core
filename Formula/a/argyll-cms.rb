class ArgyllCms < Formula
  desc "ICC compatible color management system"
  homepage "https://www.argyllcms.com/"
  url "https://www.argyllcms.com/Argyll_V3.0.2_src.zip"
  sha256 "b31ba4c055445be01d3a560cbc3a5a38c62fbd676e38d7495dc6ffc9aa3c964c"
  license "AGPL-3.0-only"

  livecheck do
    url "https://www.argyllcms.com/downloadsrc.html"
    regex(/href=.*?Argyll[._-]v?(\d+(?:\.\d+)+)[._-]src\.zip/i)
  end

  bottle do
    sha256 cellar: :any,                 arm64_sonoma:   "083267f64369a64dd0c5ed50b801270478444035dbc0675c990d9e2f5c375443"
    sha256 cellar: :any,                 arm64_ventura:  "847b973903d22bf9d4a61a1b8f1dd44e64b2a5c7fe4bb406abc9a8f79a85734c"
    sha256 cellar: :any,                 arm64_monterey: "03bd01d9a18255f331819f96758dc62096256c93657c727577532b1c573ffe35"
    sha256 cellar: :any,                 sonoma:         "907afbf5faa2049f33e9b1c05ad1db0e6beb0874eabcbbf6573e1c7bce074aa5"
    sha256 cellar: :any,                 ventura:        "9302648254a90f14748ed52470c8eb92b009520d54f847ab69165d5139217cf1"
    sha256 cellar: :any,                 monterey:       "654fd0c65d0053d04fdf92f68d3b01e3157c4889458e5f25d2975a6863b1e9fc"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "bdf87674a178a4e64514780b64cd2d96d18099cfb46f3759d0d8c7ca6e04fa78"
  end

  depends_on "jam" => :build
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libtiff"
  depends_on "openssl@3"

  uses_from_macos "zlib"

  on_linux do
    depends_on "libx11"
    depends_on "libxinerama"
    depends_on "libxrandr"
    depends_on "libxscrnsaver"
    depends_on "libxxf86vm"
    depends_on "xorgproto"
  end

  conflicts_with "num-utils", because: "both install `average` binaries"

  # Fixes a missing header, which is an error by default on arm64 but not x86_64
  patch do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/f6ede0dff06c2d9e3383416dc57c5157704b6f3a/argyll-cms/unistd_import.diff"
    sha256 "5ce1e66daf86bcd43a0d2a14181b5e04574757bcbf21c5f27b1f1d22f82a8a6e"
  end

  def install
    # Remove bundled libraries to prevent fallback
    %w[jpeg png tiff zlib].each { |l| (buildpath/l).rmtree }

    inreplace "Jamtop" do |s|
      openssl = Formula["openssl@3"]
      libname = shared_library("lib$(lcase)")

      # These two inreplaces make sure all Homebrew and SDK libraries can be found by the Jamfile
      s.gsub! "[ GLOB /usr/include$(subd) : $(lcase).h $(lcase)lib.h ]",
              "[ GLOB #{openssl.opt_include}$(subd) : $(lcase).h $(lcase)lib.h ] || " \
              "[ GLOB #{HOMEBREW_PREFIX}/include$(subd) : $(lcase).h $(lcase)lib.h ] || " \
              "[ GLOB #{MacOS.sdk_path_if_needed}/usr/include$(subd) : $(lcase).h $(lcase)lib.h ]"
      s.gsub! "[ GLOB /usr/lib : lib$(lcase).so ]",
              "[ GLOB #{openssl.opt_lib} : #{libname} ] || " \
              "[ GLOB #{HOMEBREW_PREFIX}/lib : #{libname} ] || " \
              "[ GLOB #{MacOS.sdk_path_if_needed}/usr/lib : #{libname} lib$(lcase).tbd ]"

      # These two inreplaces make sure the X11 headers can be found on Linux.
      s.gsub! "/usr/X11R6/include", HOMEBREW_PREFIX/"include"
      s.gsub! "/usr/X11R6/lib", HOMEBREW_PREFIX/"lib"
    end

    ENV["NUMBER_OF_PROCESSORS"] = ENV.make_jobs.to_s
    system "sh", "makeall.sh"
    system "./makeinstall.sh"
    rm "bin/License.txt"
    prefix.install "bin", "ref", "doc"
  end

  test do
    system bin/"targen", "-d", "0", "test.ti1"
    system bin/"printtarg", testpath/"test.ti1"
    %w[test.ti1.ps test.ti1.ti1 test.ti1.ti2].each do |f|
      assert_predicate testpath/f, :exist?
    end

    # Skip this part of the test on Linux because it hangs due to lack of a display.
    return if OS.linux? && ENV["HOMEBREW_GITHUB_ACTIONS"]

    assert_match "Calibrate a Display", shell_output("#{bin}/dispcal 2>&1", 1)
  end
end
