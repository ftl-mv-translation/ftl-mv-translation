# FTL: Multiverse 한국어 번역

## 스크립트 실행하기

스크립트는 Python으로 작성되어 있고, poetry로 관리됩니다. 다른 패키지처럼 setuptools로 직접 설치할 수도 있고, 혹은 poetry를 사용해서 virtualenv 및 설치과정을 간소화할 수도 있습니다.

`mvloc` 명령은 아래 두 가지 방식 중 하나로 실행할 수 있습니다:

1. pip로 설치하기 (virtualenv 내에서 설치하는 것을 추천)
2. poetry로 패키지를 설치하고 (`poetry install`) `poetry run mvloc` 명령으로 실행하기.

참고: `batch-`로 시작하는 모든 `mvloc` 명령은 `report.txt` 파일을 생성합니다. 이 파일 안에는 각 작업의 로그가 저장됩니다.

## 작업흐름

### 번역

이 저장소는 [Weblate](https://weblate.org/)를 사용해 번역하도록 설계되어 있습니다. 다음과 같은 Weblate 애드온 설정을 추천합니다:

* Component discovery
   ```
   Regular expression to match translation files against:
   locale/(?P<component>.*)/(?P<language>[^/.]*)\.json
   
   File format:
   JSON file
   
   Define the monolingual base filename:
   locale/{{ component }}/en.json
   
   Define the base file for new translations:
   locale/{{ component }}/en.json
   ```

* Flag unchanged translations as "Needs editing"

### 영문 스트링 업데이트하기

1. 최신 버전의 FTL: Multiverse를 src-en/ 디렉토리에 압축 해제합니다
2. `mvloc batch-en`을 실행합니다

이 명령은 `src-en/`에서 스트링을 추출해서 `locale/` 디렉토리 이하 `en.json`에 기록합니다. 이 변경이 저장소에 반영되면 Weblate가 자동으로 변경점을 추출해서 기록할 수 있습니다.

### 스트링 추출 기준 변경하기

`mvloc.config.jsonc` 파일을 수정하고, "영문 스트링 업데이트하기" 작업 흐름을 따라해주세요.

### 번역 적용하기

1. 최신 버전의 FTL: Multiverse를 src-en/ 디렉토리에 압축 해제합니다
2. `mvloc batch-apply`를 실행합니다

이 명령은 `src-en/`의 XML 파일에 `locale/`에 있는 번역을 적용해서 `output/` 디렉토리로 추출합니다.

### 부트스트래핑

1. 원문 FTL: Multiverse를 `src-en/` 디렉토리에 압축 해제합니다
2. `src-ko/` 디렉토리를 만들고 번역본 XML 파일을 보관합니다
3. `mvloc batch-bootstrap`을 실행합니다

부트스트래핑은 번역 적용의 정반대입니다. 이미 있는 번역본 XML로부터 스트링을 추출합니다. 기존에 이미 진행되고 있던 번역 프로젝트를 옮길 때 유용합니다.

## 면책 조항

FTL: Faster Than Light은 Subset Games의 상표입니다. 별도 언급이 없는 한, 이 저장소의 저자와 기여자들은 Subset Games와 관계가 없습니다.
