import sys, subprocess, pathlib, re, json
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]/'.media_tools'))
import imageio_ffmpeg
from PIL import Image, ImageDraw
ROOT=pathlib.Path(__file__).resolve().parent
SOURCE=pathlib.Path(r'C:\Users\STOCK\Downloads\LockSys_SMS_Reel.mp4')
FF=imageio_ffmpeg.get_ffmpeg_exe()
def run(args):
    return subprocess.run([FF,*args],capture_output=True)
info=run(['-i',str(SOURCE)]).stderr.decode(errors='replace')
(ROOT/'source_info.txt').write_text(info,encoding='utf-8')
print(info)
times=list(range(0,38,2))
sheet=Image.new('RGB',(5*216,4*414),(25,25,25))
draw=ImageDraw.Draw(sheet)
for i,t in enumerate(times):
    p=ROOT/f'frame_{t:02}.jpg'
    run(['-y','-ss',str(t),'-i',str(SOURCE),'-frames:v','1','-vf','scale=216:-1',str(p)])
    if p.exists():
        im=Image.open(p); x=(i%5)*216; y=(i//5)*414
        sheet.paste(im,(x,y+25)); draw.text((x+8,y+5),f'{t:02}s',fill='white')
sheet.save(ROOT/'timeline.jpg')
scenes=run(['-i',str(SOURCE),'-vf',"select='gt(scene,0.12)',showinfo",'-an','-f','null','-']).stderr.decode(errors='replace')
(ROOT/'scene_detection.txt').write_text(scenes,encoding='utf-8')
print('Scene candidates:',re.findall(r'pts_time:([\d.]+)',scenes))
