Gem::Specification.new do |s|
  s.name     = 'mormor'
  s.version  = '0.0.2'
  s.authors  = ['Victor Shepelev']
  s.email    = 'zverok.offline@gmail.com'
  s.homepage = 'https://github.com/molybdenum-99/mormor'

  s.summary = 'Morfologik dictionaries client in pure Ruby: POS tagging & spellcheck'
  s.licenses = ['MIT']

  s.required_ruby_version = '>= 2.7.0'

  s.files = `git ls-files exe lib LICENSE.txt README.md Changelog.md`.split($RS)
  s.require_paths = ["lib"]
  s.bindir = 'exe'
  s.executables << 'mormor-dump'

  s.add_runtime_dependency 'backports', '>= 3.15.0'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rubygems-tasks'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'forspell'
end
