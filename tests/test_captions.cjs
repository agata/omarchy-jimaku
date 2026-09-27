const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ctx = {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(__dirname + '/../Captions.js', 'utf8').replace('.pragma library',''), ctx);
const plain = x => JSON.parse(JSON.stringify(x));
assert.deepEqual(plain(ctx.extract('まだ途中', 40, false)), {cues:[],rest:'まだ途中'});
assert.deepEqual(plain(ctx.extract('最初の文。次の文です！続き',40,false)), {cues:['最初の文。','次の文です！'],rest:'続き'});
assert.deepEqual(plain(ctx.extract('最後は句点なし',40,true)), {cues:['最後は句点なし'],rest:''});
assert.deepEqual(plain(ctx.extract('価格は3.14ドルです。',40,false)).cues,['価格は3.14ドルです。']);
const text = 'これは長い説明で、適切な区切りで字幕を切り替えて表示します。'.repeat(10);
const parsed = ctx.extract(text,24,true);
assert.equal(parsed.cues.join(''),text);
assert.ok(parsed.cues.every(x=>Array.from(x).length<=24));
const emoji = '字幕😀'.repeat(30);
assert.equal(ctx.extract(emoji,17,true).cues.join(''),emoji);
let rest='', cues=[];
for(const c of '一つ目の文章です。二つ目の文章です。最後まで表示します！') {
  const r=ctx.extract(rest+c,24,false); rest=r.rest; cues.push(...r.cues);
}
assert.equal(cues.length,3);
assert.equal(rest,'');
assert.ok(ctx.holdTime('短い字幕',0)>=1500);
assert.ok(ctx.holdTime('長い字幕'.repeat(8),4)<ctx.holdTime('長い字幕'.repeat(8),0));
// Receiving a chunk or newline alone must not end the sentence.
assert.deepEqual(plain(ctx.extract('ここまでが最初の受信\n続きもまだ途中',40,false)).cues, []);
assert.deepEqual(plain(ctx.extract('ここは読点で区切ります、続き',40,false)), {cues:['ここは読点で区切ります、'],rest:'続き'});
assert.equal(ctx.extract('あ'.repeat(25),24,false).cues.length,0);
assert.deepEqual(plain(ctx.extract('あ'.repeat(25)+'。',24,false)).cues,['あ'.repeat(25)+'。']);
assert.ok(ctx.extract('あ'.repeat(50),24,false).cues.length>0);
assert.deepEqual(plain(ctx.extract('金額は1,000ドルです。',40,false)).cues,['金額は1,000ドルです。']);
console.log('CAPTION_SEGMENTATION_PASSED (14 cases)');
const longCue = '字幕の表示時間を検証するための文章です。'.repeat(2);
assert.equal(ctx.holdTime(longCue,0,99999),ctx.holdTime(longCue,0,0));
let last=Infinity;
for(let backlog=0;backlog<=8;backlog++) {
  const time=ctx.holdTime(longCue,backlog,0);
  assert.ok(time<=last); assert.ok(time>=400); last=time;
}
assert.ok(ctx.holdTime(longCue,1,9000)<ctx.holdTime(longCue,1,0));
const original=ctx.holdTime(longCue,0,0);
const shortened=ctx.nextDeadline(longCue,5,0,1000,1000+original);
assert.ok(shortened<1000+original);
assert.equal(ctx.nextDeadline(longCue,1,0,1000,shortened),shortened);
assert.equal(ctx.holdTime('短い字幕',8,15000),400);
console.log('ADAPTIVE_TIMING_PASSED');

for (let backlog=0; backlog<20; backlog++) {
  assert.equal(ctx.holdTime(longCue,backlog,60000,'realtime'),800);
  assert.ok(ctx.holdTime(longCue,backlog,60000,'readable')>=1000);
}
assert.equal(ctx.holdTime('短い',0,0,'readable'),2200);
assert.equal(ctx.holdTime(longCue.repeat(5),0,0,'readable'),6000);
assert.equal(ctx.nextDeadline(longCue,2,0,1000,6000,'realtime'),1800);
console.log('DISPLAY_MODES_PASSED');

assert.equal(ctx.leadingClosers('。」次の文'), '。」');
assert.equal(ctx.safeCut(Array.from('あいう「えお'), 4), 3);
assert.equal(ctx.safeCut(Array.from('あいう。）」次'), 3), 6);
const bracketed='あ'.repeat(23)+'「'+'い'.repeat(25)+'。」';
const bracketCues=ctx.extract(bracketed,24,true).cues;
assert.equal(bracketCues.join(''),bracketed);
assert.ok(bracketCues.every(c=>!/[「『（]$/.test(c)));
assert.ok(bracketCues.every(c=>! /^[。、「」）]/.test(c) || c.startsWith('「')));
console.log('BOUNDARY_PROTECTION_PASSED');
