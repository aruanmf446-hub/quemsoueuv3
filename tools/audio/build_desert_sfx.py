"""Prepare small PCM effects from Kenney Impact Sounds (CC0) and original sand layers.
Usage: python3 tools/audio/build_desert_sfx.py /path/kenney_impact-sounds.zip
"""
from pathlib import Path
import hashlib,json,subprocess,sys,wave,zipfile
import numpy as np
root=Path(__file__).resolve().parents[2]/'assets/audio/desert_sfx'
rate=44100
archive=Path(sys.argv[1]);pack=zipfile.ZipFile(archive)
manifest=json.loads((root/'sources.json').read_text())
for name in ['footstep_concrete_000','footstep_concrete_001','footstep_wood_000','footstep_wood_001']:
 blob=pack.read('Audio/'+name+'.ogg');source=Path('/tmp')/(name+'.ogg');source.write_bytes(blob)
 target=root/(name+'.wav')
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-af','highpass=f=55,lowpass=f=8500,afade=t=in:st=0:d=0.003,alimiter=limit=0.78:level=false','-ar',str(rate),'-ac','1','-c:a','pcm_s16le',str(target)],check=True)
 manifest['files']=[item for item in manifest['files'] if item['file']!=target.name]
 manifest['files'].append({'file':target.name,'source':'Kenney Impact Sounds / Audio/'+name+'.ogg','source_sha256':hashlib.sha256(blob).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
# Verify that the pinned mirror used for the first files matches the official archive.
for item in manifest['files']:
 name=Path(item['file']).stem
 if name.startswith('impact_'):
  kind=name.split('_')[1];name='impact'+kind.capitalize()+name[len('impact_'+kind):]
 original=pack.read('Audio/'+name+'.ogg')
 assert hashlib.sha256(original).hexdigest()==item['source_sha256'],item['file']
manifest['official_pack_sha256']=hashlib.sha256(archive.read_bytes()).hexdigest()
manifest['verified_against_official_archive']=True
rng=np.random.default_rng(1907)
def load(name):
 with wave.open(str(root/(name+'.wav'))) as sound:return np.frombuffer(sound.readframes(sound.getnframes()),dtype='<i2').astype(float)/32768

def fit(data,length):
 size=round(length*rate)
 return np.interp(np.linspace(0,len(data)-1,size),np.arange(len(data)),data)

def band(data,low,high):
 f=np.fft.rfftfreq(len(data),1/rate);fft=np.fft.rfft(data)
 taper=(1-np.exp(-(f/max(low,1))**4))*np.exp(-(f/high)**6)
 return np.fft.irfft(fft*taper,n=len(data))

def breeze(length):
 noise=rng.normal(0,1,round(length*rate))
 return band(noise,180,4200)*np.sin(np.linspace(0,np.pi,len(noise)))**1.4

def write(name,data,origins):
 data=band(data,65,7800)
 size=len(data);fade=min(round(.006*rate),size//2)
 data[:fade]*=np.linspace(0,1,fade);data[-fade:]*=np.linspace(1,0,fade)
 rms=np.sqrt(np.mean(data**2));peak=max(np.abs(data).max(),.0001)
 data*=min(.74/peak,.16/max(rms,.0001))
 target=root/(name+'.wav')
 with wave.open(str(target),'wb') as out:
  out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate)
  out.writeframes(np.clip(data*32767,-32767,32767).astype('<i2').tobytes())
 return {'file':target.name,'source':origins,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}

derived=[]
carpet=load('footstep_carpet_000');snow=load('footstep_snow_000')
derived.append(write('sand_swing',breeze(.22)*.45+fit(carpet[::-1],.22)*.20,'Original filtered noise + Kenney footstep_carpet_000 reversed'))
derived.append(write('sand_jump',fit(snow,.18)*.55+breeze(.18)*.12,'Kenney footstep_snow_000 + original air'))
derived.append(write('sand_double_jump',fit(snow[::-1],.32)*.38+breeze(.32)*.50,'Kenney footstep_snow_000 reversed + original air'))
derived.append(write('sand_fall',breeze(.64)*.40,'Original filtered air, no synthetic whistle'))
bell=band(load('impact_bell_heavy_000'),170,3200)
small=fit(bell[:round(.30*rate)],.26)*np.exp(-np.arange(round(.26*rate))/rate/.12)
derived.append(write('collect',small,'Kenney impact_bell_heavy_000, filtered and shortened'))
chime=np.zeros(round(.70*rate));chime[:len(small)]+=small*.8
start=round(.17*rate);second=fit(small,.31);chime[start:start+len(second)]+=second*.45
chime=band(chime,150,3500)
derived.append(write('save',chime,'Kenney impact_bell_heavy_000, two quiet resonances'))
manifest['derived']=derived
(root/'sources.json').write_text(json.dumps(manifest,indent=2))
print('Prepared',len(manifest['files'])+len(derived),'effects; official archive verified')
