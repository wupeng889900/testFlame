import urllib.request,re
for url in ['https://static.itch.io/extern.min.js?1776446284','https://static.itch.io/bundle.min.js?1776446284','https://static.itch.io/lib.min.js?1776446284']:
    js = urllib.request.urlopen(url).read().decode('utf-8','ignore')
    print('\nURL', url)
    for pat in ['init_GameDownload','GameDownload','upload_id','download_btn','download/upload']:
        idx = js.find(pat)
        print(pat, idx)
        if idx != -1:
            print(js[max(0,idx-300):idx+1200])
