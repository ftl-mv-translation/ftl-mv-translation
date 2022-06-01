from mvlocscript.potools import readpo, writepo
from mvlocscript.fstools import glob_posix as glob
from pathlib import Path

REPLACE_MAP = {
    'Decline.': 'Ablehnen.',
    'Attack!': 'Angriff!',
    'Nevermind.': 'Doch nicht.',
    'Return.': 'Zurück.',
    'Yes.': 'Ja.',
    'No.': 'Nein.',
    'Yes': 'Ja',
    'No': 'Nein',
    'Projectile': 'Projektil',
    'Servant': 'Diener',
    'Success!': 'Erfolgreich!',
    'Continue....': 'Fortfahren....',
    'Continue.': 'Fortfahren.',
    'Leave.': 'Gehe wieder.',
    'Accept.': 'Akzeptieren.',
    'You install the upgrade.': 'Du installierst das Upgrade.',
    'You install the modification.': 'Du installierst die Modifikation.',
    'Install the Power Module.': 'Installiere das Kraft Modul.',
    'Install the Cooldown Module.': 'Installiere das Abkühlungs Modul.',
    'Install the Lockdown Module.': 'Installiere das Einschließungs Modul.',
    'Install the Pierce Module.': 'Installiere das Durchdringungs Modul.',
    'Install the Neural Module.': 'Installiere das Neural Modul.',
    'Install the Firestarter Module.': 'Installiere das Brandstarter Modul.',
    'Install the Hullbuster Module.': 'Installiere das Hüllenzerbrecher Modul.',
    'Install the Accuracy Module.': 'Installiere das Genauigkeits Modul.',
    'Install the Anti-Bio Module.': 'Installiere das Anti-Bio Modul.',
}

for path in glob('locale/**/de.po'):
    dict_original, _, sourcelocation = readpo(Path(path).parent / 'en.po')
    dict_translated, _, _ = readpo(path)

    changed = False

    for key in list(dict_translated):
        entry_translated = dict_translated[key]
        if entry_translated.obsolete:
            continue
        entry_original = dict_original[key]

        target = REPLACE_MAP.get(entry_original.value, None)
        if target is None:
            continue
        dict_translated[key] = entry_translated._replace(value=target)
        changed = True

    if changed:
        writepo(path, dict_translated.values(), sourcelocation)
