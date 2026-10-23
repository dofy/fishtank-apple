// Synthetic parity fixtures only. The web checkout is a read-only reference.
// node tools/export-web-reforge.mjs /absolute/path/to/fishtank
import {writeFile} from 'node:fs/promises'
import {resolve, join} from 'node:path'
import {pathToFileURL, fileURLToPath} from 'node:url'
if (!process.argv[2]) throw new Error('Pass the original fishtank checkout path.')
const root = resolve(process.argv[2])
const {createServer} = await import(pathToFileURL(join(root, 'node_modules/vite/dist/node/index.js')))
const server = await createServer({root, configFile:false, server:{middlewareMode:true,watch:null,hmr:false}})
try {
  const game = await server.ssrLoadModule('/src/core/game.ts')
  const {reforge} = await server.ssrLoadModule('/src/core/reforge.ts')
  const {HIDDEN_SPECIES} = await server.ssrLoadModule('/src/core/species.ts')
  const {Rng} = await server.ssrLoadModule('/src/core/rng.ts')
  const now = 1_800_000_000_000, samples = []
  for (const seed of [1,7,42,12345,0x12345678,0xffffffff]) {
    for (const history of [[],['lanternangler'],['lanternangler','glassangel'],HIDDEN_SPECIES.map(s=>s.id)]) {
      for (const misses of [0,6,9]) {
        const state = game.newGame(now, 'zh')
        state.reforgeMisses = misses
        for (const id of history) game.recordVariant(state,id,1)
        const materials = [1,2,5].map(grade=>game.makeFish('prismkoi',5,grade,now,{adult:true,uses:0}))
        state.fish.push(...materials)
        const result = reforge(state, materials.map(f=>f.uid), now, new Rng(seed))
        if ('error' in result) throw new Error(result.error)
        samples.push({seed,history,misses,species:result.child.speciesId,grade:result.child.grade,
          uses:result.child.uses,novel:result.novel,guaranteed:result.guaranteed,afterMisses:state.reforgeMisses})
      }
    }
  }
  await writeFile(fileURLToPath(new URL('../Tests/Fixtures/reforge-parity.json',import.meta.url)),JSON.stringify(samples,null,2)+'\n')
  console.log(`Exported ${samples.length} synthetic reforge parity cases`)
} finally { await server.close() }
