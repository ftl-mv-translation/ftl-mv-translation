from google.oauth2.service_account import Credentials
import gspread
from pathlib import Path
from time import sleep
from mvlocscript.potools import readpo
from mvlocscript.fstools import glob_posix

SERVICE_ACCOUNT_FILE_PATH = ''
WORKBOOK_ID = ''
EXCLUDE_LANG = ['en', 'und', 'ang']

scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
]

credentials = Credentials.from_service_account_file(SERVICE_ACCOUNT_FILE_PATH, scopes=scopes)
gc = gspread.authorize(credentials)

wb = gc.open_by_key(WORKBOOK_ID)

list_of_languages = set(Path(path).stem for path in glob_posix('locale/**/*.po'))
print(list_of_languages)

for lang_index, lang in enumerate(list_of_languages):
    if lang in EXCLUDE_LANG:
        continue
    print(f'dealing with {lang}...')
    request = []

    cells = [[]]
    
    for i, filepath_original in enumerate(glob_posix('locale/**/en.po')):
        dict_original, _, _ = readpo(filepath_original)
        filepath_translated = Path(filepath_original).with_stem(lang)
        dict_translated = {}
        if filepath_translated.exists():
            dict_translated, _, _ = readpo(str(filepath_translated))
        
        
        cells[0].extend([f'{Path(filepath_original).parent.parent.name}/{Path(filepath_original).parent.name}', '', ''])
        for j, entry in enumerate(dict_original.values()):
            translated_entry = dict_translated.get(entry.key, None)
            if len(cells) < j + 2:
                cells.append([])
            while len(cells[j + 1]) < i * 3:
                cells[j + 1].append('')
            if translated_entry:
                cells[j + 1].extend([entry.key, entry.value, translated_entry.value])
            else:
                cells[j + 1].extend([entry.key, entry.value, ''])
        
    request_data_encode = []
    for data in cells:
        row_list = []
        for color_index, text in enumerate(data):
            if text:
                row_list.append({
                    "userEnteredFormat": {
                        "wrapStrategy": "WRAP",
                        "verticalAlignment": "TOP",
                        "backgroundColorStyle": {
                            "rgbColor": {
                                "red": 1.0,
                                "green": 1.0,
                                "blue": 1.0
                            } if (color_index // 3) % 2 == 0 else
                            {
                                "red": 0.8,
                                "green": 0.8,
                                "blue": 0.8
                            }
                        }
                    },
                    'userEnteredValue':{
                        'stringValue': text
                    },
                })
            else:
                row_list.append({
                    "userEnteredFormat": {
                        "wrapStrategy": "WRAP",
                        "verticalAlignment": "TOP",
                        "backgroundColorStyle": {
                            "rgbColor": {
                                "red": 1.0,
                                "green": 1.0,
                                "blue": 1.0
                            } if (color_index // 3) % 2 == 0 else
                            {
                                "red": 0.8,
                                "green": 0.8,
                                "blue": 0.8
                            }
                        }
                    },
                })
        request_data_encode.append({
            'values': row_list,
        })
    row_length = len(cells)
    column_length = max([len(cell) for cell in cells])
    new_id = lang_index + 1

    request.extend([
        {
            'addSheet':{
                'properties': {
                    'sheetId': new_id,
                    'title': lang,
                    "gridProperties":{
                        "rowCount": row_length,
                        "columnCount": column_length,
                    }
                }
            },
        },
        {
            'appendCells':{
                'sheetId': new_id,
                'rows': request_data_encode,
                'fields': 'userEnteredFormat.wrapStrategy, userEnteredFormat.verticalAlignment, userEnteredFormat.backgroundColorStyle, userEnteredValue',
            }
        },
        {
            'autoResizeDimensions':{
                "dimensions": {
                    "sheetId": new_id,
                    "dimension": 'ROWS',
                    "startIndex": 0,
                },
            }
        },
        {
            'updateDimensionProperties': {
                'range': {
                    'sheetId': new_id,
                    'dimension': 'COLUMNS',
                    'startIndex': 0,
                    'endIndex': column_length - 1,
                },
                'properties': {
                    'pixelSize': 370,
                },
                'fields': 'pixelSize',
            },
        },
    ])
    wb.batch_update({'requests': request})
    sleep(1.2)