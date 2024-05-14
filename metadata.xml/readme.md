metadata.xml/ is for mod description for mvinstaller. While SMM cannot recognize non-Latin characters, mvinstaller can.

You can make translated metadata.xml as `<lang code>.xml` in this folder(en.xml is a sample).

If the file in your locale exists here, nightly releases it instead of locale/mod-appendix/metadata.xml(or locale-machine/mod-appendix/metadata.xml), which is from weblate translation. It means description here(translated) is used for mvinstaller, weblate text(original English) is used for SMM.

Once you put your file here, you should rewrite text in weblate in English, so that SMM can recognize it correctly.

If the file in your locale does not exist here, it means mvinstaller uses weblate text as well as SMM does.
