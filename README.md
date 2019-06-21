# MorMor

[![Gem Version](https://badge.fury.io/rb/mormor.svg)](http://badge.fury.io/rb/mormor)

**MorMor** is pure Ruby [morfologik](https://github.com/morfologik/morfologik-stemming) dictionary client that could be used for POS (part of speech) tagging and simplistic spellchecking. _Morfologik_ format's distinguishing feature is it is primary dictionary format for [LanguageTool](https://github.com/languagetool-org/languagetool), therefore a lot of ready high-quality dictionaries exist.

## Features/Problems

* **No dependencies¹, pure Ruby**
* **Fast**: I don't have any detailed numbers, but naive test on my laptop shows 3 mln lookups/second on a very large dictionary (Polish, several million word forms).
* Relatively **memory-efficient**: Typical dictionary file size is 1-3 Mb, mormor just loads it into memory as bytes (e.g. each byte => Ruby Integer) and that's all memory it needs.
* **Dictionaries** for a lot of languages already exist: unlike your typical POS tagger, usage instructions does not start with "First, take your corpora and train the tagger as you please" (see "Dictionaries" section).
* To the moment, it is just a **naive** port of original Morfologik Java code, but it works with all the dictionaries I could find:
  * Of possible dictionary formats, only FSA5 and CFSA2 are implemented (not CFSA);
  * Of possible dictionary "encoders", only "SUFFIX" and "PREFIX" are implemented;
* No tests/specs, but it works (and checked thoroughly with existing dictionaries); TBH, original Morfologik doesn't have much, either;
* Morfologik's spellchecker suggestions/candidates are **not** ported, so mormor can be used only for "sanity" spellchecking ("this word is/is not in the dictionary")

<small>¹The only runtime dependency is [backports](https://github.com/marcandre/backports) and that's only because I am too fond of modern Ruby features to sacrifice them to "no-dependencies" god.</small>

## Usage

0. Install `mormor` gem (via bundler or just `[sudo] gem install mormor`)
1. Take a dictionary for your language (see "Dictionaries" section below)
2. Now...

```ruby
require 'mormor'

dictionary = MorMor::Dictionary.new('path/to/english')
dictionary.lookup('meowing')
# => [#<struct MorMor::Dictionary::Word stem="meow", tags="VBG">]
dictionary.lookup('barks')
# => [#<struct MorMor::Dictionary::Word stem="bark", tags="NNS">,
#     #<struct MorMor::Dictionary::Word stem="bark", tags="VBZ">]
dictionary.lookup('borogoves')
# = nil

dictionary = MorMor::Dictionary.new('path/to/ukrainian')
dictionary.lookup("солов'їна")
# => [#<struct MorMor::Dictionary::Word stem="солов'їний", tags="adj:f:v_kly">,
#     #<struct MorMor::Dictionary::Word stem="солов'їний", tags="adj:f:v_naz">]
```

`Dictionary#lookup` returns an array of structs which describe all possible base forms + part of speech /word form tags. (For example, "barks" could be a third person form of the verb "to bark", or plural form of noun "bark".)

Tags are dependent on the particular dictionary used and typically documented in a free form alongside the dictionaries.

## Dictionaries

A lot of dictionaries in Morfologik format could be found at [LanguageTool's repo](https://github.com/languagetool-org/languagetool). For example, for Polish language, [dictionary is at](https://github.com/languagetool-org/languagetool/tree/master/languagetool-language-modules/pl/src/main/resources/org/languagetool/resource/pl) `languagetool-language-modules/pl/src/main/resources/org/languagetool/resource/pl/`.

What you need there, are:
* `polish.dict` is a dictionary (binary finite-state-automata) itself
* `polish.info` is dictionary metadata

In order to use Polish dictionary with mormor, you need to place both files at the same folder, and then
```ruby
pl = MorMor::Dictionary.new('path/to/that/folder/polish') # without extension
pl.lookup('świetnie')
```

You may also be interested in `tagset.txt` file of the same folder, which has an explanation for all POS/forms tags in natural language (Polish language, for that case).

Sometimes (for example, in case of German and Ukrainian), LanguageTool repo contains not the dictionary itself, but a link to other repo/site where it can be downloaded.

Please **carefully consider** dictionary licenses when using them!

> **Note:** mormor repo contains copies of dictionary files from LanguageTool and referred projects, but they are **not** a part of the gem distribution and only used for testing the parser/lookup correctness, and demonstration purposes.

## License and credits

Most of the credit for algorithms and original code belong to original [Morfologik's](https://github.com/morfologik/morfologik-stemming) authors, and author of paper's they based their work on.

Ruby version is done by [Victor Shepelev](https://zverok.github.io).

The license is BSD, the same as the original Morfologik.