import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import type { Context } from '@deepseek-ai/cordis'

export const name = 'dsh-grill'
export const inject = ['skills']

interface ParsedSkill {
  name: string
  description: string
  content: string
  modelInvocable: boolean
}

function parseSkill(md: string): ParsedSkill {
  const m = md.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/)
  if (!m) throw new Error('Skill file missing YAML frontmatter')
  const front = m[1]
  const content = m[2].trim()

  const name = front.match(/^name:\s*(.+)$/m)?.[1]?.trim()
  const description = front.match(/^description:\s*(.+)$/m)?.[1]?.trim()
  if (!name || !description) throw new Error('Skill missing name or description')

  const disableModel = /^disable-model-invocation:\s*true\s*$/m.test(front)
  return { name, description, content, modelInvocable: !disableModel }
}

function loadSkills(): ParsedSkill[] {
  const here = dirname(fileURLToPath(import.meta.url))
  const skillsRoot = join(here, '..', 'skills')
  const out: ParsedSkill[] = []
  for (const dir of readdirSync(skillsRoot)) {
    const file = join(skillsRoot, dir, 'SKILL.md')
    if (existsSync(file)) out.push(parseSkill(readFileSync(file, 'utf8')))
  }
  return out
}

export function apply(ctx: Context) {
  // Register skills
  for (const skill of loadSkills()) {
    ctx.skills.register({
      name: skill.name,
      description: skill.description,
      content: skill.content,
      source: 'runtime',
      invocation: {
        modelInvocable: skill.modelInvocable,
        userInvocable: true,
      },
    })
  }
}