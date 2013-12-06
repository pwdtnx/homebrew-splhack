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
    def envpath(env)
        "~/.anyenv/envs/#{env}/bin/#{env}"
    end

    python2 = '2.7.6'
    python3 = '3.3.3'
    ruby19 = '1.9.3-p484'
    ruby20 = '2.0.0-p353'
    lua51 = '5.1.5'
    lua52 = '5.2.2'
    luajit = '2.0.2'

    prefix_python2 = `#{envpath("pyenv")} prefix #{python2}`.chomp
    prefix_python3 = `#{envpath("pyenv")} prefix #{python3}`.chomp
    prefix_ruby19 = `#{envpath("rbenv")} prefix #{ruby19}`.chomp
    prefix_ruby20 = `#{envpath("rbenv")} prefix #{ruby20}`.chomp
    prefix_lua51 = `#{envpath("luaenv")} prefix #{lua51}`.chomp
    prefix_lua52 = `#{envpath("luaenv")} prefix #{lua52}`.chomp
    prefix_luajit = `#{envpath("luaenv")} prefix luajit-#{luajit}`.chomp

    ENV["HOMEBREW_CCCFG"] = "bi6" if build.with? 'binary-release'
    ENV.remove_macosxsdk
    ENV.macosxsdk '10.7'
    ENV.append 'MACOSX_DEPLOYMENT_TARGET', '10.7'
    ENV.append 'CFLAGS', '-mmacosx-version-min=10.7'
    ENV.append 'LDFLAGS', '-mmacosx-version-min=10.7 -headerpad_max_install_names'
    ENV.append 'VERSIONER_PERL_VERSION', '5.12'
    ENV.append 'VERSIONER_PYTHON_VERSION', '2.7'
    ENV.append 'vi_cv_path_python3', "#{prefix_python3}/bin/python"
    ENV.append 'vi_cv_path_python', "#{prefix_python2}/bin/python"
    ENV.append 'vi_cv_path_ruby', "#{prefix_ruby20}/bin/ruby"
    # ENV.append 'vi_cv_path_ruby19', "#{prefix_ruby19}/bin/ruby"
    ENV.append 'vi_cv_path_lua52', "#{prefix_lua52}/bin/lua"
    ENV.append 'vi_cv_path_lua', "#{prefix_lua51}/bin/lua"
    ENV.append 'vi_cv_path_luajit', "#{prefix_luajit}/bin/luajit"

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
                          '--enable-luainterp=dynamic',
                          '--enable-lua52interp=dynamic',
                          '--enable-perlinterp'

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

    cp "#{prefix_luajit}/lib/libluajit-5.1.#{luajit}.dylib", frameworks
    File.open(vimdir + 'vimrc', 'a').write <<EOL
let $LUA_DLL = simplify($VIM . '/../../Frameworks/libluajit-5.1.#{luajit}.dylib')
EOL
  end
end
