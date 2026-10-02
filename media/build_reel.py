"""Build the 37-second reel: original H.264 stream + centered speech + original music."""
import sys,pathlib,subprocess,json,wave,math
import numpy as np
ROOT=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent/'.media_tools'))
import imageio_ffmpeg
FF=imageio_ffmpeg.get_ffmpeg_exe()
PLAN=json.loads((ROOT/'scene_plan.json').read_text())
SR=48000; DUR=PLAN['duration']; N=round(DUR*SR)
def ff(args):
 p=subprocess.run([FF,'-hide_banner','-y',*args],capture_output=True)
 if p.returncode: raise RuntimeError(p.stderr.decode(errors='replace'))
 return p
def save(path,a):
 with wave.open(str(path),'wb') as w:
  w.setnchannels(1 if a.ndim==1 else a.shape[1]);w.setsampwidth(2);w.setframerate(SR)
  w.writeframes((np.clip(a,-1,1)*32767).astype('<i2').tobytes())
voice=np.zeros(N); report=[]
for i,scene in enumerate(PLAN['scenes']):
 raw=ff(['-i',str(ROOT/f'voice_{i+1}.mp3'),'-f','f32le','-ac','1','-ar',str(SR),'pipe:1']).stdout
 a=np.frombuffer(raw,dtype='<f4').copy()
 # Trim codec padding and outer silence only; preserve pauses inside sentences.
 envelope=np.convolve(np.abs(a),np.ones(480)/480,mode='same')
 active=np.where(envelope>0.003)[0]
 if not len(active):raise RuntimeError('Silent narration')
 a=a[max(0,active[0]-2400):min(len(a),active[-1]+4800)]
 start=scene['voice_start']; available=scene['voice_end_limit']-start
 factor=max(1,len(a)/SR/available)
 if factor>1.20:raise RuntimeError(f'Line {i+1} needs natural TTS regeneration: {len(a)/SR:.2f}s for {available:.2f}s')
 save(ROOT/'temp_voice.wav',a)
 filters=f'highpass=f=75,lowpass=f=14000,acompressor=threshold=0.12:ratio=2:attack=15:release=120:makeup=1.3,atempo={factor:.6f}'
 a=np.frombuffer(ff(['-i',str(ROOT/'temp_voice.wav'),'-af',filters,'-f','f32le','-ac','1','-ar',str(SR),'pipe:1']).stdout,dtype='<f4').copy()
 a*=10**(-3/20)/max(np.max(np.abs(a)),1e-9)
 fade=min(240,len(a)//4);a[:fade]*=np.linspace(0,1,fade);a[-fade:]*=np.linspace(1,0,fade)
 at=round(start*SR);voice[at:at+len(a)]+=a
 report.append({'line':i+1,'start':start,'end':start+len(a)/SR,'tempo_factor':factor})
save(ROOT/'narration.wav',voice)
# Original mellow technology bed: suspended/major seventh pads and a sparse bell motif.
music=np.zeros((N,2),dtype=np.float64)
chords=[[50,57,61,64,69],[45,52,57,61,64],[54,61,64,69,73],[52,59,62,66,69]]
for bar in range(10):
 start=bar*4.; length=min(6,DUR-start)
 if length<=0:break
 t=np.arange(round(length*SR))/SR
 env=np.minimum(t/1.3,1)*np.minimum((length-t)/1.8,1)
 for j,note in enumerate(chords[bar%4]):
  f=440*2**((note-69)/12)
  for c in range(2):
   tone=np.sin(2*np.pi*f*(1+(-1 if c==0 else 1)*0.0006)*t+j*.37)
   tone+=.14*np.sin(2*np.pi*f*2*t)
   a=round(start*SR);music[a:a+len(t),c]+=tone*env*.021
for k in range(54):
 start=.8+k*(2/3); length=min(2.6,DUR-start)
 if length<=0:break
 t=np.arange(round(length*SR))/SR
 note=[73,76,81,76,69,76,78,76][k%8];f=440*2**((note-69)/12)
 bell=(np.sin(2*np.pi*f*t)+.18*np.sin(2*np.pi*f*2*t))*np.exp(-t*3)*np.minimum(t/.015,1)
 a=round(start*SR);pan=.3 if k%2 else .7
 music[a:a+len(t),0]+=bell*.036*pan;music[a:a+len(t),1]+=bell*.036*(1-pan)
t=np.arange(N)/SR
music*= (np.minimum(t/.8,1)*np.minimum((DUR-t)/1.8,1))[:,None]
save(ROOT/'music_original.wav',music)
out=ROOT/'LockSys_SMS_Reel_Final.mp4'
graph='[1:a]asplit=2[v][key];[2:a][key]sidechaincompress=threshold=0.018:ratio=5:attack=20:release=350:makeup=1[m];[v][m]amix=inputs=2:normalize=0,alimiter=limit=0.8913:level=false:latency=true[a]'
ff(['-i',PLAN['source'],'-i',str(ROOT/'narration.wav'),'-i',str(ROOT/'music_original.wav'),'-filter_complex',graph,'-map','0:v:0','-map','[a]','-c:v','copy','-c:a','aac','-b:a','192k','-ar','48000','-t',str(DUR),'-movflags','+faststart',str(out)])
analysis=ff(['-i',str(out),'-vn','-af','ebur128=peak=true','-f','null','-']).stderr.decode(errors='replace')
(ROOT/'final_loudness.txt').write_text(analysis,encoding='utf-8')
(ROOT/'timing_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2));print(analysis[-1100:]);print(out)
