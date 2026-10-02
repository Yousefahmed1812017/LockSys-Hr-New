import sys,pathlib,asyncio,json
ROOT=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent/'.media_tools'))
import edge_tts
LINES=[
 'لسه بتبلّغ موظفينك وعملاءك يدوي؟',
 'دلوقتي مع لوك سيس، تقدر تبعت رسائل إس إم إس تلقائيًا مباشرة من النظام.',
 'تأكيد حضور وانصراف، إشعارات للعملاء والموردين، وتنبيهات العمليات المهمة...',
 'كلها بتوصل فورًا على الموبايل، من غير تدخل يدوي.',
 'النتيجة؟',
 'تواصل أسرع، أخطاء أقل، وتجربة أفضل لموظفينك وعملائك.',
 'لوك سيس سوليوشنز... خليك متصل.'
]
async def main():
 for i,line in enumerate(LINES):
  p=ROOT/f'voice_{i+1}.mp3'
  if p.exists() and p.stat().st_size>1000: continue
  await edge_tts.Communicate(line,'ar-EG-ShakirNeural',rate='+0%',pitch='-2Hz').save(str(p))
  print('Generated',i+1,flush=True)
asyncio.run(main())
