from mvlocscript.potools import readpo, writepo
from mvlocscript.fstools import glob_posix as glob
from pathlib import Path


FACTION_END = {
    "Geniocracy":"de la Géniocratie",
    "Federation":"de la Fédération",
    "Union":"de l'Union",
    "Inquisition":"de l'Inquisition",
    "CDEG":"du CDEG",
    "Elite":"d'Elite",
    "Engi":"Engi",
    "Harmony":"de l'Harmonie",
    "Ministry":"du Ministère",
    "Zoltan":"Zoltan",
    "Peace-Keeping":"des Gardiens de la Paix",
    "Illesctrian":"des Illesctrian",
    "Gathering":"du Rassemblement",
    "Chieftain":"des Cheftain",
    "Confederate":"des Confédérés",
    "Free Mantis":"des Mantis-Libre",
    "Warlord":"de Chef Militaire",
    "Radiant":"des Radieux",
    "Geniocracy Science":"des Scientifiques de la Géniocratie",
    "Geniocracy Management":"des Managers de la Géniocratie",
    "Geniocracy Militant":"des Soldats de la Géniocratie",
    "Lost Sun":"du Soleil-Perdus",
    "Separatist":"des Séparatistes",
    "Imperial":"de l'Empire",
    "SSLG":"du SSLG",
    "Sentinel":"des Sentinelles",
    "Wrecked":"Ravagé",
    "Spectral":"Spectral",
    "Reaper":"des Faucheuses",
    "Dynasty":"de la Dynastie",
    "Siren":"des Sirènes",
    "Kleptocracy":"de la Kleptocracie",
    "Clairvoyant":"des Clairvoyants",
    "Knighted":"Chevalier",
    "Guild":"de la Guilde",
    "Hektar":"d'Hektar(tm)'",
    "Eargen":"des Eargens",
    "Revolutionary":"des Révolutionnaires",
    "Ampere":"de l'Ampère",
    "Lanius":"des Lanius",
    "Swarm":"de l'Essaim",
    "Rebel":"Rebel",
    "MFK":"des MFK Ace",
    "Legionnaire":"des Légionnaires",
    "MV":"MV",
    "Engineer":"des Engineer",
    "Auto-":"Automatisé",
    "Innovation":"d'Innovation'",
    "Technician":"de Technicien",
    "Coalition":"de la Coalition",
    "R.U.E.S.":"R.U.E.S.",
    "Theocracy":"de la Théocracie",
    "Outcast":"des Rejetés",
    "Paladin":"des Paladins",
    "Hive":"de la Ruche",
    "Suzerain":"des Suzerains",
    "Bishop":"des Evêques",
    "Duskbringer":"du Crépuscule",
    "Extremist":"des Extrémistes",
    "Augmented":"des Augmentés",
    "Obelisk":"des Obélisques",
    "Ancient":"Ancien",
    "Obelisk Royal":"de la Lignée Royale",
    "Guardian":"des Guardiens",
    "Ember":"de l'Ambre",
    "Multiverse":"du Multivers",
    "Multiverse Renegade":"Renégat du Multivers",
    "Renegade":"des Renégats",
    "Pirate":"Pirate",
    "Tiiikaka":"des Tiiikaka",
    "Syndicate":"du Syndicat",
    "Argeonn":"des Argeonn",
    "Hacker":"d'Hacker",
    "Brood":"de la Couvée",
    "Hephaestus":"Hephaestus",
    "Haunted":"Hanté",
    "Traveling Merchant":"Marchand Itinérant",
    "Orchid":"des Orchidées",
    "SDM":"du SDM",
    "SDM":"du SDM",
    "SDM":"du SDM",
    "SDM":"du SDM",
    "SDM":"du SDM",
}

SHIP_TYPE = {
    "Scout":"Eclaireur",
    "Outrider":"Explorateur",
    "Miner":"Prospecteur",
    "Investigator":"Inspecteur",
    "Shuttle":"Capsule",
    "Carryship":"Transporteur",
    "Transport":"Transport",
    "Station":"Station",
    "Refueling Station":"Station d'Essence",
    "Fighter":"Chasseur",
    "Bomber":"Bombardier",
    "Bombard":"Bombardier",
    "Destroyer":"Destroyer",
    "Escort":"Escorte",
    "Guard":"Guarde",
    "Enforcer":"Exécuteur",
    "Strike Fighter":"Chasseur Avancé",
    "Tactical Fighter":"Chasseur Tactique",
    "Rigger":"Gréeur",
    "Corvette":"Corvette",
    "Assault":"Assaut",
    "Light Cruiser":"Croiseur Léger",
    "Battleship":"Cuirassé",
    "Picket":"Piquet",

    "Infiltrator":"Infiltrateur",
    "Mothership":"Vaisseau-Mère",
    "Trapper":"Trappeur",
    "Protector":"Protecteur",
    "Instigator":"Instigateur",
    "Investigator":"Enquêteur",
    "Abductor":"Enleveur",
    "Minelayer":"Mineur",
    "Operator":"Opérateur",
    "Lift-Ship":"Vaisseau-Porteur",
    "Dreadnaught":"Cuirassé Lourd",
    "Marauder":"Maraudeur",
    "Skirmisher":"Tirailleur",
    "Dropship":"Transporteur",
    "Dropship":"Transporteur",
    

}

for path in glob('locale/data/autoBlueprints.xml.append/fr.po'):
    dicto, _, sourcelocation = readpo(Path(path).parent / 'en.po') #Get pos original
    dictt, _, _ = readpo(path) #Get pos translated

    changed = False

    for k in list(dictt):
        fuz = False
        idt = dictt[k]

        if idt.obsolete or idt.fuzzy or idt.value != "": #not gonna overwrite something already done 
            continue
        
        ido = dicto[k]
        ido_val = ido.value

        end = None
        for i in FACTION_END: #Check The Faction
            if ido_val.find(i) >= 0:
                end = FACTION_END[i]
                ido_val = ido_val.replace(i+' ','')

        start = None
        for i in SHIP_TYPE: #Check The Ship Type
            if ido_val.find(i) >= 0:
                start = SHIP_TYPE[i]
                ido_val = ido_val.replace(i,'')

        if end is not None and start is not None: 
            ido_val = start + " " + end
            changed = True

        elif end is not None:

            if ido_val != "":
                ido_val = ido_val + " " + end
            else:
                ido_val = end
            fuz = True
            changed = True

        elif start is not None:
            ido_val = start + " " + ido_val
            fuz = True
            changed = True
        

        dictt[k] = idt._replace(value=ido_val)
        if fuz: #If not complete conversion we mark them as fuzzy for further verification
            dictt[k] = dictt[k]._replace(fuzzy=True)
        

    if changed:
        writepo(path, dictt.values(), sourcelocation)
