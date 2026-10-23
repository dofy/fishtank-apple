#!/usr/bin/env python3
"""Audit English catalog keys, Swift call sites, all four catalogs, placeholders and README navigation."""
from pathlib import Path
import re,json
WRAPPERS=('L10n.text(', 'L10n.source(', 'L10n.message(')
# SwiftUI entry points whose first argument reaches the screen directly.
DISPLAY=re.compile(r'(?:Text|Button|PixelIconButton)\($|\.(?:help|navigationTitle|accessibilityLabel|accessibilityValue|accessibilityHint)\($')
# Decorative glyphs and identifiers that never need translation.
EXEMPT=re.compile(r'^[\W\d_★☆]*$|^\{\d+\}$')
# Product name and level marker read the same in every supported language.
ALLOWED={'Fishtank ','Lv.{0}'}
records={}
unwrapped=[]
chinese=[]
def region(s, path):
 out='';i=0
 while i<len(s):
  if s.startswith('//',i):
   j=s.find('\n',i);j=len(s) if j<0 else j;out+=s[i:j];i=j;continue
  if s.startswith('/*',i):
   j=s.find('*/',i+2);j=len(s)-2 if j<0 else j;out+=s[i:j+2];i=j+2;continue
  if s[i]!='"':out+=s[i];i+=1;continue
  start=i;i+=1;raw='';template='';n=0
  while i<len(s):
   if s[i]=='"':i+=1;break
   if s.startswith('\\(',i):
    j=i+2;depth=1
    while j<len(s) and depth:
     if s[j]=='"':
      k=j+1
      while k<len(s):
       if s[k]=='\\':k+=2;continue
       if s[k]=='"':k+=1;break
       k+=1
      j=k;continue
     if s[j]=='(':depth+=1
     if s[j]==')':depth-=1
     j+=1
    expression=region(s[i+2:j-1],path)
    raw+='\\('+expression+')';template+='{'+str(n)+'}';n+=1;i=j;continue
   if s[i]=='\\' and i+1<len(s):raw+=s[i:i+2];template+=s[i:i+2];i+=2;continue
   raw+=s[i];template+=s[i];i+=1
  literal='"'+raw+'"'
  try:key=json.loads('"'+template+'"')
  except Exception:raise ValueError((path,template))
  if re.search('[一-鿿]',key):chinese.append((str(path),key))
  line=s[s.rfind('\n',0,start)+1:start]
  if line.endswith(WRAPPERS):records.setdefault(key,[]).append(str(path))
  elif DISPLAY.search(line) and not EXEMPT.match(key) and key not in ALLOWED:unwrapped.append((str(path),key))
  out+=literal
 return out

if __name__ == '__main__':
    for p in Path('Sources').rglob('*.swift'):
        if p.name != 'L10n.swift': region(p.read_text(), p)
    assert not chinese, ('Chinese source literals; catalog keys are English', chinese)
    assert not unwrapped, ('Unlocalized display literals', unwrapped)
    expected = set(records)
    expression = re.compile(r'\{\d+\}|%[0-9]*[a-zA-Z]')
    for language in ['en', 'zh-Hans', 'zh-Hant', 'ja']:
        data = json.loads(Path('Sources/Core/Resources/Localizations', language+'.json').read_text())
        assert set(data) == expected, (language, 'catalog keys differ', expected-set(data), set(data)-expected)
        for key, value in data.items():
            assert isinstance(value,str) and value, (language,key)
            assert sorted(expression.findall(key)) == sorted(expression.findall(value)), (language,key,'placeholder mismatch')
            # English keys are the source text; a trailing [marker] only separates identical renderings.
            if language == 'en': assert value == re.sub(r' \[[^\]]*\]$','',key), ('English catalog must repeat its key',key,value)
        print('PASS',language,len(data),'templates, interpolation and source coverage')
    for name in ['README.md','README.zh-Hans.md','README.zh-Hant.md','README.ja.md']:
        text=Path(name).read_text()
        assert not re.search(r'\b\d+\.\d+\.\d+\b',text), ('Version in README',name)
        for target in re.findall(r'(?:src|href)="([^"]+)"|\]\(([^)]+)\)',text):
            link=next(item for item in target if item)
            if not link.startswith(('https:','http:','#')): assert Path(link.split('#')[0]).exists(),(name,link)
        assert len(re.findall(r'docs/screenshots/[^)]+',text)) == 6, name
    print('PASS four version-independent product READMEs and local links')
