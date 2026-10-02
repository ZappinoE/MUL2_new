base = r'C:\Users\d026646\OneDrive - Politecnico di Torino\Documenti\POLITO\CLAUDE\MUL2_NEW\DOC\BOOKS\user'
p = base + r'\03_tutorial.md'
t = open(p, encoding='utf-8').read()
t = t.replace("in the order of Figure {fig:el-2d} of the Theoretical Guide (corners and mid-sides alternate, the centre last).",
              "in the order of Figure {fig:el2d-user} (corners and mid-sides alternate counter-clockwise, the centre last).")
t = t.replace("must follow Figure {fig:el-2d} of the Theoretical Guide.", "must follow Figure {fig:el2d-user}.")
t = t.replace("## Step 4 – the frame (VERSORS.dat)", "![Node order of the quadrilateral elements.](figures/elements_2d.svg){#fig:el2d-user}\n\n## Step 4 – the frame (VERSORS.dat)", 1)
open(p, 'w', encoding='utf-8').write(t)
q = base + r'\app_a_quickref.md'
a = open(q, encoding='utf-8').read()
a = a.replace("## Frames\n", "![Beam elements.](figures/elements_1d.svg){#fig:el1d-user}\n\n![Triangles.](figures/elements_tri.svg){#fig:eltri-user}\n\n![Hexahedra.](figures/elements_3d.svg){#fig:el3d-user}\n\n## Frames\n", 1)
open(q, 'w', encoding='utf-8').write(a)
r = base + r'\04_input_reference.md'
c = open(r, encoding='utf-8').read()
c = c.replace("(Figures of Chapter 3 of the Theoretical Guide)", "(Figure {fig:el2d-user} and the quick reference, Appendix A)")
c = c.replace("follows its topology (Figures of Chapter 3 of the Theoretical Guide).", "follows its topology (Figure {fig:el2d-user} and the quick reference).")
c = c.replace("follows the element node order (Figures of Chapter 3 of the Theoretical Guide)", "follows the element node order (Figure {fig:el2d-user} and the quick reference)")
open(r, 'w', encoding='utf-8').write(c)
print('ok')
