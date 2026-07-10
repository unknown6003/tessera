import { content } from '../../data/spec'
import { Reveal } from './Reveal'
import { SectionHeading } from './SectionHeading'
import { Card } from '#/components/ui/card.tsx'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '#/components/ui/table.tsx'
import { Check, X } from 'lucide-react'
import { cn } from '#/lib/utils.ts'

/** Render one comparison value: a mark for Yes/No, dimmed text otherwise. */
function Value({ value, tessera }: { value: string; tessera: boolean }) {
  if (value === 'Yes')
    return (
      <Check
        className={cn(
          'mx-auto size-5',
          tessera ? 'text-brand' : 'text-foreground/70',
        )}
        strokeWidth={2.4}
      />
    )
  if (value === 'No')
    return (
      <X className="mx-auto size-4 text-muted-foreground/40" strokeWidth={2} />
    )
  // text values (price, "Partial")
  return (
    <span
      className={cn(
        'text-[0.85rem]',
        tessera ? 'font-semibold text-brand' : 'text-muted-foreground',
      )}
    >
      {value}
    </span>
  )
}

export function Compare() {
  const { comparison } = content
  const [, ...products] = comparison.columns // drop the empty label column

  return (
    <section id="compare" className="section scroll-mt-20">
      <div className="container-wrap">
        <SectionHeading
          kicker="Honest comparison"
          title={comparison.headline}
          subtitle={comparison.subhead}
        />

        <Reveal className="mx-auto mt-12 max-w-3xl">
          <Card className="overflow-hidden p-0">
            <div className="overflow-x-auto">
              <Table className="min-w-[560px]">
                <TableHeader>
                  <TableRow className="border-border hover:bg-transparent">
                    <TableHead className="w-[34%]" />
                    {products.map((name, i) => (
                      <TableHead
                        key={name}
                        className={cn(
                          'text-center text-[0.85rem] font-semibold',
                          i === 0
                            ? 'bg-brand/[0.06] text-brand'
                            : 'text-muted-foreground',
                        )}
                      >
                        {name}
                      </TableHead>
                    ))}
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {comparison.rows.map((row) => (
                    <TableRow key={row.label} className="border-border/60">
                      <TableCell className="text-[0.85rem] font-medium text-foreground">
                        {row.label}
                      </TableCell>
                      {row.values.map((v, vi) => (
                        <TableCell
                          key={vi}
                          className={cn(
                            'text-center',
                            vi === 0 && 'bg-brand/[0.06]',
                          )}
                        >
                          <Value value={v} tessera={vi === 0} />
                        </TableCell>
                      ))}
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </Card>
        </Reveal>
      </div>
    </section>
  )
}
