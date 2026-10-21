// Development-only bridge to the original repository. Not used by app builds.
// node tools/generate-web-fixtures.mjs /absolute/path/to/fishtank
import {writeFile} from 'node:fs/promises';
import {resolve, join} from 'node:path';
import {pathToFileURL, fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
if (!process.argv[2]) throw new Error('Pass the original fishtank checkout path.');
const source = resolve(process.argv[2]);
const {createServer} = await import(pathToFileURL(join(source, 'node_modules/vite/dist/node/index.js')));
const server = await createServer({root: source, configFile: false, server: {middlewareMode: true, watch: null, hmr: false}});
try {
  const {SPECIES} = await server.ssrLoadModule('/src/core/species.ts');
  const balance = await server.ssrLoadModule('/src/core/balance.ts');
  const game = await server.ssrLoadModule('/src/core/game.ts');
  const {Rng} = await server.ssrLoadModule('/src/core/rng.ts');
  const now = 1800000000000, breeds = [], merges = [];
  for (let a = 0; a <= 5; a++) for (let b = a; b <= 5; b++) for (const seed of [1, 7, 42, 12345, 4294967295]) {
    const state = game.newGame(now, 'zh');
    state.fish = [game.makeFish(SPECIES.find(s => s.tier === a).id, a, 2, now, {adult: true}),
                  game.makeFish(SPECIES.find(s => s.tier === b).id, b, 4, now, {adult: true})];
    state.tankUids = [];
    const result = game.breed(state, state.fish[0].uid, state.fish[1].uid, now, new Rng(seed));
    const child = result.child;
    const sample = {a, b, seed, species: child.speciesId, tier: child.tier, grade: child.grade, uses: child.uses,
      birthExp: child.birthExp, exp: state.exp, level: state.level,
      parents: state.fish.slice(0, 2).map(f => ({uses: f.uses, cooldown: f.maturesAt === null ? 0 : f.maturesAt - now}))};
    game.tick(state, now + balance.GROWTH_MS_BY_TIER[child.tier]);
    sample.matureExp = state.exp;
    breeds.push(sample);
  }
  for (const tiers of [Array(10).fill(1), Array(10).fill(4), [1,1,1,1,1,1,1,1,2,4]]) for (const seed of [1,7,42,12345,4294967295]) {
    const state = game.newGame(now, 'zh');
    state.fish = tiers.map((t, i) => game.makeFish(SPECIES.find(s => s.tier === t).id, t, i === 0 ? 5 : 1, now, {adult: true}));
    state.tankUids = [];
    const result = game.synthesize(state, state.fish.map(f => f.uid), now, new Rng(seed));
    const child = result.child;
    game.tick(state, now + balance.GROWTH_MS_BY_TIER[child.tier]);
    merges.push({tiers, seed, species: child.speciesId, tier: child.tier, grade: child.grade, uses: child.uses, matureExp: state.exp});
  }
  const revision = execFileSync('git', ['rev-parse', '--short', 'HEAD'], {cwd: source, encoding: 'utf8'}).trim();
  const target = fileURLToPath(new URL('../Tests/Fixtures/web-parity.json', import.meta.url));
  await writeFile(target, JSON.stringify({source: `fishtank ${revision} / src/core/game.ts`, now: now / 1000, breeds, merges}, null, 2));
  console.log(`Wrote ${breeds.length} breeding and ${merges.length} merge fixtures.`);
} finally { await server.close(); }
