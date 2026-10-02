import sys,pathlib,subprocess,json,numpy as np
ROOT=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent/'.media_tools'))
import imageio_ffmpeg
FF=imageio_ffmpeg.get_ffmpeg_exe()
source=r'C:\Users\STOCK\Downloads\LockSys_SMS_Reel.mp4'
final=str(ROOT/'LockSys_SMS_Reel_Final.mp4')
def run(args):
 p=subprocess.run([FF,'-hide_banner',*args],capture_output=True)
 if p.returncode:raise RuntimeError(p.stderr.decode(errors='replace'))
 return p
hashes=[run(['-i',p,'-map','0:v:0','-c','copy','-f','hash','-hash','sha256','-']).stdout.decode().strip() for p in [source,final]]
if hashes[0]!=hashes[1]:raise RuntimeError('Video stream differs')
decoded=run(['-v','error','-i',final,'-f','null','-'])
pcm=np.frombuffer(run(['-i',final,'-vn','-ac','2','-ar','48000','-f','f32le','-']).stdout,dtype='<f4').reshape(-1,2)
peak=float(np.max(np.abs(pcm)));clip=int(np.sum(np.abs(pcm)>=1))
result={'video_stream_identical':True,'video_sha256':hashes[0], 'full_decode_errors':decoded.stderr.decode(),'audio_duration_seconds':len(pcm)/48000,'audio_sample_rate':48000,'audio_channels':2,'sample_peak_dbfs':20*np.log10(peak),'clipped_samples':clip,'last_100ms_rms':float(np.sqrt(np.mean(pcm[-4800:]**2))),'timings':json.loads((ROOT/'timing_report.json').read_text())}
(ROOT/'qc_report.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
