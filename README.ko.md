# FTL: Multiverse 번역 프로젝트

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
   locale/(?P<component>.*)/(?P<language>[^/.]*)\.po
   
   File format:
   gettext PO file (monolingual)
   
   Define the monolingual base filename:
   locale/{{ component }}/en.po
   
   Define the base file for new translations:
   locale/{{ component }}/en.po
   ```

### 영문 스트링 업데이트하기

1. 최신 버전의 FTL: Multiverse를 src-en/ 디렉토리에 압축 해제합니다
2. `mvloc batch-generate --clean en`을 실행합니다

이 명령은 `src-en/`에서 스트링을 추출해서 `locale/` 디렉토리 이하 `en.po`에 기록합니다.
이 변경이 저장소에 반영되면 Weblate가 자동으로 변경점을 추출해서 기록할 수 있습니다.

### 스트링 추출 기준 변경하기

`mvloc.config.jsonc` 파일을 수정하고, "영문 스트링 업데이트하기" 작업 흐름을 따라해주세요.

### 번역 적용하기

1. 최신 버전의 FTL: Multiverse를 src-en/ 디렉토리에 압축 해제합니다
2. `mvloc batch-apply <언어이름>`을 실행합니다 -- 예: `mvloc batch-apply ko`

이 명령은 `src-en/`의 XML 파일에 `locale/`에 있는 번역을 적용해서 `output/` 디렉토리에 저장합니다.

### 부트스트래핑

1. 원문 FTL: Multiverse를 `src-en/` 디렉토리에 압축 해제합니다
2. `src-<언어이름>/` 디렉토리를 만들고 번역본 XML 파일을 보관합니다 -- 예: `src-ko/`
3. `mvloc batch-generate --diff --clean --empty-identical <언어이름>`을 실행합니다

부트스트래핑은 번역 적용의 정반대입니다. 이미 있는 번역본 XML로부터 스트링을 추출합니다.
기존에 이미 진행되고 있던 번역 프로젝트를 옮길 때 유용합니다.

만약 스트링 추출 기준이 불완전한 경우, XML의 모든 번역문을 추출하지 못할 수도 있습니다. 이 경우 report.txt 파일 내에
추출되지 못한 변경점들이 표시됩니다 ("Diff report"). 이를 참조하여, "스트링 추출 기준 변경하기" 및
"영문 스트링 업데이트하기" 작업흐름을 따라해주시고, 그 다음 이 작업을 다시 시도해주시면 됩니다.

> #### 일부 파일만 부트스트래핑하는 경우
>
> * 부트스트래핑 할 파일만 `src-<언어이름>/`에 넣어주세요.  해당 디렉토리에 다른 파일이 남아있으면 안 됩니다.
> * 실행시 `--clean` 옵션을 지워주세요. 그럼 해당 파일만 변경되고 나머지 파일들은 변경되지 않습니다.

## 면책 조항

FTL: Faster Than Light은 Subset Games의 상표입니다. 별도 언급이 없는 한, 이 저장소의 저자와 기여자들은
Subset Games와 관계가 없습니다.
