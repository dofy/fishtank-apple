// Regenerate decoration/music definitions and achievement reference cases from the original checkout.
// node tools/export-web-extras.mjs /absolute/path/to/fishtank
import {readFile, writeFile} from 'node:fs/promises';
import {resolve, join} from 'node:path';
import {pathToFileURL, fileURLToPath} from 'node:url';
if (!process.argv[2]) throw new Error('Pass the original checkout path.');
const source = resolve(process.argv[2]);
const {createServer} = await import(pathToFileURL(join(source, 'node_modules/vite/dist/node/index.js')));
const server = await createServer({root: source, configFile: false, server: {middlewareMode: true, watch: null, hmr: false}});
try {
  const {DECORATIONS, SPECIES} = await server.ssrLoadModule('/src/core/species.ts');
  const game = await server.ssrLoadModule('/src/core/game.ts');
  const milestones = await server.ssrLoadModule('/src/core/milestones.ts');
  const i18n = await readFile(join(source, 'src/core/i18n.ts'), 'utf8');
  const names = Object.fromEntries([...i18n.slice(i18n.indexOf('const DECOR_ZH'), i18n.indexOf('const TIER_ZH')).matchAll(/\s+(\w+): '([^']+)'/g)].map(m => [m[1], m[2]]));
  const audio = await readFile(join(source, 'src/core/audio.ts'), 'utf8');
  const chunk = audio.slice(audio.indexOf('const TRACKS:'));
  // Evaluate only the developer-owned, literal pattern table; no downloaded source is executed.
  const tracks = Function('return (' + chunk.slice(chunk.indexOf('{'), chunk.indexOf('\nclass SoundEngine')).trim().replace(/;$/, '') + ')')();
  const copy = await readFile(join(source, 'src/ui/milestones.ts'), 'utf8');
  const copies = Object.fromEntries([...copy.slice(copy.indexOf('const entries:'), copy.indexOf('} : {')).matchAll(/'([^']+)': \{ title: '([^']+)', note: '([^']+)'/g)].map(m => [m[1], {title:m[2], note:m[3]}]));
  await writeFile('/tmp/fishtank-extras-data.json', JSON.stringify({decorations:DECORATIONS.map(d=>({...d,zh:names[d.id]})), tracks, milestones:milestones.MILESTONES.map(m=>({...m,...copies[m.id]}))}));
  const variants = [[], ['copperband:1'], ['moonjelly:1','crystaljelly:2','astraljelly:5'], ['ambereel:1','volteel:2','auroraeel:3'], [1,2,3,4,5].map(g=>'copperband:'+g), SPECIES.map(s=>s.id+':1'), SPECIES.flatMap(s=>[1,2,3,4,5].map(g=>s.id+':'+g))];
  const achievements = variants.map(variants=>{
    const state=game.newGame(1800000000000); state.fish=[];state.discovered=[];state.discoveredVariants=variants;
    milestones.syncMilestones(state);
    return {variants,progress:milestones.milestoneProgress(state),unlocked:state.milestones.unlocked};
  });
  const state=game.newGame(1800000000000);state.exp=57760;state.level=10;
  for(const item of DECORATIONS) game.toggleDecor(state,item.id);
  const placements=structuredClone(state.placedDecor),moveId=state.placedDecor[0].id;
  game.moveDecor(state,moveId,-2);game.flipDecor(state,moveId);
  await writeFile(fileURLToPath(new URL('../Tests/Fixtures/extras-parity.json',import.meta.url)),JSON.stringify({achievements,placements,moveId,moved:state.placedDecor},null,2));
  console.log('Exported extras patterns and 7 achievement histories.');
} finally { await server.close(); }
