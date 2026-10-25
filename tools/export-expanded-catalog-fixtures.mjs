// Independent gameplay reference with the native-only species injected in memory.
// The original Web checkout, its catalog and its historical fixtures stay intact.
// node tools/export-expanded-catalog-fixtures.mjs /absolute/path/to/fishtank
import {readFile, writeFile} from 'node:fs/promises'
import {resolve, join} from 'node:path'
import {pathToFileURL, fileURLToPath} from 'node:url'
import {execFileSync} from 'node:child_process'

if (!process.argv[2]) throw new Error('Pass the reference Web checkout path.')
const root = resolve(process.argv[2])
const {createServer} = await import(pathToFileURL(join(root, 'node_modules/vite/dist/node/index.js')))
const injected = `{ id: 'cuttlefish', name: 'Cuttlefish', tier: 5, body: { form: 'fish', silhouette: 'broad-mantle', length: 21, depth: 0.72, tail: 0.2, dorsal: 0.7, pattern: 'bands', hue: 28, sat: 0.55, light: 0.65 } },\n`
let patched = false
const server = await createServer({root, configFile: false,
  plugins: [{name: 'native-cuttlefish-reference', enforce: 'pre', transform(code, id) {
    if (!id.split('?')[0].endsWith('/src/core/species.ts')) return
    const marker = '  // Secret creatures never enter ordinary breeding or synthesis pools.'
    if (!code.includes(marker) || code.includes("id: 'cuttlefish'")) throw new Error('Unexpected reference catalog')
    patched = true
    return {code: code.replace(marker, injected + marker), map: null}
  }}], server: {middlewareMode: true, watch: null, hmr: false}})
try {
  const species = await server.ssrLoadModule('/src/core/species.ts')
  const game = await server.ssrLoadModule('/src/core/game.ts')
  const {reforge} = await server.ssrLoadModule('/src/core/reforge.ts')
  const milestones = await server.ssrLoadModule('/src/core/milestones.ts')
  const balance = await server.ssrLoadModule('/src/core/balance.ts')
  const {Rng} = await server.ssrLoadModule('/src/core/rng.ts')
  if (!patched || species.REGULAR_SPECIES.length !== 30) throw new Error('Catalog injection failed')
  const now = 1_800_000_000_000, breeds = [], merges = [], reforges = []
  for (let a = 0; a <= 5; a++) for (let b = a; b <= 5; b++) for (const seed of [1, 7, 42, 12345, 0xffffffff]) {
    const state = game.newGame(now, 'zh')
    state.fish = [a, b].map((tier, i) => game.makeFish(species.poolForTier(tier)[0].id, tier, i === 0 ? 2 : 4, now, {adult: true}))
    state.tankUids = []
    const result = game.breed(state, state.fish[0].uid, state.fish[1].uid, now, new Rng(seed))
    if ('error' in result) throw new Error(result.error)
    const child = result.child
    const sample = {a, b, seed, species: child.speciesId, tier: child.tier, grade: child.grade, uses: child.uses,
      birthExp: child.birthExp, exp: state.exp, level: state.level,
      parents: state.fish.slice(0, 2).map(f => ({uses: f.uses, cooldown: f.maturesAt === null ? 0 : f.maturesAt - now}))}
    game.tick(state, now + balance.GROWTH_MS_BY_TIER[child.tier])
    breeds.push({...sample, matureExp: state.exp})
  }
  for (const tiers of [Array(10).fill(1), Array(10).fill(4), [1,1,1,1,1,1,1,1,2,4]]) for (const seed of [1,7,42,12345,0xffffffff]) {
    const state = game.newGame(now, 'zh')
    state.fish = tiers.map((tier, i) => game.makeFish(species.poolForTier(tier)[0].id, tier, i === 0 ? 5 : 1, now, {adult: true}))
    state.tankUids = []
    const result = game.synthesize(state, state.fish.map(f => f.uid), now, new Rng(seed))
    if ('error' in result) throw new Error(result.error)
    const child = result.child
    game.tick(state, now + balance.GROWTH_MS_BY_TIER[child.tier])
    merges.push({tiers, seed, species: child.speciesId, tier: child.tier, grade: child.grade, uses: child.uses, matureExp: state.exp})
  }
  for (const seed of [1,7,42,12345,0x12345678,0xffffffff]) {
    for (const history of [[], ['lanternangler'], ['lanternangler','glassangel'], species.HIDDEN_SPECIES.map(s => s.id)]) {
      for (const misses of [0,6,9]) {
        const state = game.newGame(now, 'zh'); state.reforgeMisses = misses
        for (const id of history) game.recordVariant(state, id, 1)
        const materials = [1,2,5].map(grade => game.makeFish('prismkoi',5,grade,now,{adult:true,uses:0}))
        state.fish.push(...materials)
        const result = reforge(state,materials.map(f => f.uid),now,new Rng(seed))
        if ('error' in result) throw new Error(result.error)
        reforges.push({seed,history,misses,species:result.child.speciesId,grade:result.child.grade,uses:result.child.uses,
          novel:result.novel,guaranteed:result.guaranteed,afterMisses:state.reforgeMisses})
      }
    }
  }
  const legacy = JSON.parse(await readFile(fileURLToPath(new URL('../Tests/Fixtures/extras-parity.json',import.meta.url))))
  const achievements = legacy.achievements.map(({variants}) => {
    const state = game.newGame(now, 'zh'); state.fish = []; state.tankUids = []
    state.discovered = []; state.discoveredVariants = variants; state.milestones = {unlocked: []}
    const progress = milestones.milestoneProgress(state)
    return {variants,progress,unlocked:progress.filter(p => p.unlocked).map(p => p.id)}
  })
  const revision = execFileSync('git',['rev-parse','--short','HEAD'],{cwd:root,encoding:'utf8'}).trim()
  const fixture = {source:`fishtank ${revision}; unmodified gameplay with cuttlefish catalog entry injected in memory`,now:now/1000,breeds,merges,reforges,achievements}
  await writeFile(fileURLToPath(new URL('../Tests/Fixtures/cuttlefish-catalog-parity.json',import.meta.url)),JSON.stringify(fixture,null,2)+'\n')
  console.log(`Exported ${breeds.length} breeds, ${merges.length} merges, ${reforges.length} reforges and ${achievements.length} collection histories`)
} finally { await server.close() }
