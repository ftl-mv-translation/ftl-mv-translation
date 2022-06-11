from snippets.mass_edits import mass_translate

REPLACE_MAP = {
    "YOU SHOULD NEVER SEE THIS.": "DU SOLLTEST DAS NIEMALS SEHEN.",
    "Use your blessing to avoid combat.": "Nutze deinen Segen um dem Kampf auszuweichen.",
    "Fires a blast of debris across a random area doing up to 3 damage.": "Feuert eine Ladung von Trümmern, in einem zufälligen Radius, die bis zu 3 Schaden machen.",
    "You start calibrating the drone...": "Du beginnst die Drohne zu kalibrieren...",
    "You finish calibrating the drone successfully.": "Du beendest die Kalibrierung der Drohne erfolgreich.",
    "Your crew cannot be cloned on your ship as they are inside the cannon.": "Deine Crew kann nicht geklont werden, da sie in der Kannone sind.",
    "Return to the toggle menu.": "Kehre zum Toggle Menu zurück",
    "You start the process.": "Du startest den Prozess.",
    "You finish the process.": "Du beendest den Prozess.",
    "Exit hyperspeed.": "Verlasse Lichtgeschwindigkeit.",
    "Are you sure? You will not be able to retrieve them without a Clone Bay, and all skills will be lost.": "Bist du sicher? Du wirst sie nicht ohne eine Klon-Kammer zurück holen können und alle Skills gehen verloren.",
    "You reset the weapon.": "Du stellst den Anfangszustand der Waffe wieder her.",
    "You finish resetting the weapon.": "Du hast den Anfangszustand erfolgreich wiederhergestellt.",
    "Reset the cannon.": "Starte die Kannone von neu.",
    "(Clone Bay) Revive your crew.": "(Klon-Kammer) Hole deine Crew zurück.",
    "Though your crew's memories have been almost completely erased, they remember enough to at least remain loyal to the Federation.": "Obwohl die Erinnerungen deiner Crew komplett gelöscht wurden, erinnert sie sich an genug, um Loyal zur Föderation zu sein.",
    "No modules attached.": "Keine Module installiert.",
    "Reroute.": "Neuen Kurs wählen.",
    "Ignore them.": "Ignoriere sie.",
    "No weapon has ever sparked a larger ethical controversy, but if it works it works.": "Keine Waffe hat jemals eine größere ethische Konversation gestartet, aber wenn es funktioniert, funktioniert es.",
    "Your Morph transforms into a new shape.": "Dein Morph verwandelt sich in eine neue Gestalt.",
}

mass_translate('locale/**/de.po', REPLACE_MAP, overwrite=False)
