require 'formula'

class MacvimKaoriya < Formula
  homepage 'http://code.google.com/p/macvim-kaoriya/'
  head 'https://github.com/splhack/macvim.git'

  depends_on 'cmigemo-mk' => :build
  depends_on 'ctags-objc-ja' => :build
  depends_on 'gettext-mk' => :build

  option 'with-binary-release', ''

  GETTEXT = "#{HOMEBREW_PREFIX}/Cellar/gettext-mk/0.18.1.1"

  def install
    python2 = '2.7.6'
    python3 = '3.3.3'
    perl518 = '5.18.0'
    ruby20 = '2.0.0-p353'
    lua51 = '5.1.5'
    lua52 = '5.2.2'
    luajit = '2.0.2'

    ENV["HOMEBREW_CCCFG"] = "bi6" if build.with? 'binary-release'
    ENV.remove_macosxsdk
    ENV.macosxsdk '10.7'
    ENV.append 'MACOSX_DEPLOYMENT_TARGET', '10.7'
    ENV.append 'CFLAGS', '-mmacosx-version-min=10.7'
    ENV.append 'LDFLAGS', '-mmacosx-version-min=10.7 -headerpad_max_install_names'
    ENV.append 'VERSIONER_PERL_VERSION', '5.12'
    ENV.append 'VERSIONER_PYTHON19_VERSION', '2.7'
    
    ENV.append 'vi_cv_path_python', "#{`brew --cellar python`}/#{python2}/bin/python"
    ENV.append 'vi_cv_path_python3', "#{`brew --cellar python3`}/#{python3}/bin/python3"
    ENV.append 'vi_cv_path_ruby', "#{`brew --cellar ruby`}/#{ruby20}/bin/ruby"
    ENV.append 'vi_cv_path_lua', "#{`brew --cellar lua`}/#{lua51}/bin/lua"
    ENV.append 'vi_cv_path_lua52', "#{`brew --cellar lua52`}/#{lua52}/bin/lua"
    ENV.append 'vi_cv_path_luajit', "#{`brew --cellar luajit`}/#{luajit}/bin/luajit"

    system './configure', "--prefix=#{prefix}",
                          '--with-features=huge',
                          '--enable-multibyte',
                          '--enable-netbeans',
                          '--with-tlib=ncurses',
                          '--enable-cscope',
                          '--enable-perlinterp=dynamic',
                          '--enable-pythoninterp=dynamic',
                          '--enable-python3interp=dynamic',
                          '--enable-rubyinterp=dynamic',
                          '--enable-ruby19interp=dynamic',
                          '--enable-perlinterp=dynamic',
                          '--enable-luainterp=dynamic',
                          "--with-lua-prefix=#{`brew --cellar lua`}/#{lua51}",
                          '--enable-lua52interp=dynamic',
                          "--with-lua52-prefix=#{`brew --cellar lua52`}/#{lua52}"

    gettext = "#{GETTEXT}/bin/"
    inreplace 'src/po/Makefile' do |s|
      s.gsub! /^(MSGFMT\s*=.*)(msgfmt.*)/, "\\1#{gettext}\\2"
      s.gsub! /^(XGETTEXT\s*=.*)(xgettext.*)/, "\\1#{gettext}\\2"
      s.gsub! /^(MSGMERGE\s*=.*)(msgmerge.*)/, "\\1#{gettext}\\2"
    end

    inreplace 'src/auto/config.mk' do |s|
      s.gsub! "-L#{HOMEBREW_PREFIX}/Cellar/readline/6.2.2/lib", ''
    end

    Dir.chdir('src/po') {system 'make'}
    system 'make'

    prefix.install 'src/MacVim/build/Release/MacVim.app'

    app = prefix + 'MacVim.app/Contents'
    frameworks = app + 'Frameworks'
    macos = app + 'MacOS'
    vimdir = app + 'Resources/vim'
    runtime = vimdir + 'runtime'

    macos.install 'src/MacVim/mvim'
    mvim = macos + 'mvim'
    ['vimdiff', 'view', 'mvimdiff', 'mview'].each do |t|
      ln_s 'mvim', macos + t
    end
    inreplace mvim do |s|
      s.gsub! /^# (VIM_APP_DIR=).*/, "\\1`dirname \"$0\"`/../../.."
      s.gsub! /^(binary=).*/, "\\1\"`(cd \"$VIM_APP_DIR/MacVim.app/Contents/MacOS\"; pwd -P)`/Vim\""
    end

    cp "#{HOMEBREW_PREFIX}/bin/ctags", macos

    dict = runtime + 'dict'
    mkdir_p dict
    Dir.glob("#{HOMEBREW_PREFIX}/share/migemo/utf-8/*").each do |f|
      cp f, dict
    end

    [
      "#{HOMEBREW_PREFIX}/opt/gettext-mk/lib/libintl.8.dylib",
      "#{HOMEBREW_PREFIX}/lib/libmigemo.1.1.0.dylib",
    ].each do |lib|
      newname = "@executable_path/../Frameworks/#{File.basename(lib)}"
      system "install_name_tool -change #{lib} #{newname} #{macos + 'Vim'}"
      cp lib, frameworks
    end

    cp "#{`brew --cellar luajit`}/#{luajit}/lib/libluajit-5.1.#{luajit}.dylib", frameworks
    File.open(vimdir + 'vimrc', 'a').write <<EOL
let $LUA_DLL = simplify($VIM . '/../../Frameworks/libluajit-5.1.#{luajit}.dylib')
EOL
  end
end
