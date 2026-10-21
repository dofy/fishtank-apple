// Read-only reference export using the original game's own save validator.
import {writeFile} from 'node:fs/promises';
import {resolve, join} from 'node:path';
import {pathToFileURL, fileURLToPath} from 'node:url';
const source = resolve(process.argv[2]);
const {createServer} = await import(pathToFileURL(join(source,'node_modules/vite/dist/node/index.js')));
const server = await createServer({root:source,configFile:false,server:{middlewareMode:true,watch:null,hmr:false}});
try {
 const game = await server.ssrLoadModule('/src/core/game.ts');
 const save = await server.ssrLoadModule('/src/core/save.ts');
 const {SPECIES} = await server.ssrLoadModule('/src/core/species.ts');
 const state = game.newGame(1800000000000,'zh');
 state.exp=57760;state.level=10;
 for(const s of SPECIES.filter(s=>s.tier>0)) {
  const f=game.makeFish(s.id,s.tier,5,1800000000000,{adult:true});
  state.fish.push(f);game.recordVariant(state,f.speciesId,f.grade);
 }
 state.fish[3].nickname='保留的旧昵称';state.fish[3].favorite=true;state.fish[3].locked=true;
 state.placedDecor=[{id:'kelp',x:0.14,flip:1},{id:'arch',x:0.6,flip:-1},{id:'fairylights',x:0.5,flip:1}];
 state.audio={sfxEnabled:false,sfxVolume:0.3,bgmEnabled:true,bgmVolume:0.2,bgmTrack:'tide'};
 state.railLights={animated:false,frequency:1.2};state.colorMode='dark';
 state.tankUids=state.fish.slice(0,12).map(f=>f.uid);
 const valid=save.parseSaveImport(save.exportSave(state,1800000000000),1800000000000);
 await writeFile(fileURLToPath(new URL('../Tests/Fixtures/web-save.json',import.meta.url)),save.exportSave(valid.state,1800000000000));
 console.log('Exported original validated web save: '+valid.state.fish.length+' fish.');
} finally { await server.close(); }
