from snippets.mass_edits import mass_translate

REPLACE_MAP = {
    "Your Morph transforms into a new shape.": "당신의 모프가 새로운 형태로 변합니다.",
    "YOU SHOULD NEVER SEE THIS": "YOU SHOULD NEVER SEE THIS",
    "YOU SHOULD NEVER SEE THIS.": "YOU SHOULD NEVER SEE THIS.",
    "Explored location. Nothing left of interest.": "이미 방문한 송신소입니다. 더 이상 흥미로운 것은 없습니다.",
    "Nevermind, do something else.": "아무것도 아니다. 무언가 다른 일을 하자.",
    "An unvisited location.": "방문하지 않은 송신소입니다.",
}

mass_translate('locale/**/ko.po', REPLACE_MAP, overwrite=True)
