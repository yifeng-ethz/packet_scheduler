#! /usr/bin/env python3
import math
import dislin

  
dislin.metafl ('cons')
dislin.setpag ('da4p')
dislin.scrmod ('reverse')

dislin.disini ()
dislin.pagera ()
dislin.complx ()
dislin.height (40)

cstr = 'TeX Instructions for Mathematical Formulas'
nl = dislin.nlmess (cstr)
dislin.messag (cstr, (2100 - nl)//2, 100)
  
dislin.texmod ('on')

dislin.messag ('$\\frac{1}{x+y}$', 150, 400)
dislin.messag ('$\\frac{a^2 - b^2}{a+b} = a - b$', 1200, 400)
  
dislin.messag ('$r = \\sqrt{x^2 + y^2}', 150, 700)
dislin.messag ('$\\cos \\phi = \\frac{x}{\\sqrt{x^2 + y^2}}$', 1200, 700)

dislin.messag ('$\\Gamma(x) = \\int_0^\\infty e^{-t}t^{x-1}dt$', 150, 1000)
dislin.messag ('$\\lim_{x \\to \\infty} (1 + \\frac{1}{x})^x = e$', 1200, 1000)

dislin.messag ('$\\mu = \\sum_{i=1}^n x_i p_i$', 150, 1300)
dislin.messag ('$\\mu = \\int_{-\\infty}^ \\infty x f(x) dx$', 1200, 1300)

dislin.messag ('$\\overline{x} = \\frac{1}{n} \\sum_{i=1}^n x_i$', 150, 1600)
dislin.messag ('$s^2 = \\frac{1}{n-1} \\sum_{i=1}^n (x_i - \\overline{x})^2$', 1200, 1600)

dislin.messag ('$\\sqrt[n]{\\frac{x^n - y^n}{1 + u^{2n}}}$', 150, 1900)  
dislin.messag ('$\\sqrt[3]{-q + \\sqrt{q^2 + p^3}}$', 1200, 1900)

dislin.messag ('$\\int \\frac{dx}{1+x^2} = \\arctan x + C$', 150, 2200)
dislin.messag ('$\\int \\frac{dx}{\\sqrt{1+x^2}} = {\\rm arsinh} x + C$',1200, 2200)

dislin.messag ('$\\overline{P_1P_2} = \\sqrt{(x_2-x_1)^2 + (y_2-y_1)^2}$', 150,2500)
dislin.messag ('$x = \\frac{x_1 + \\lambda x_2}{1 + \\lambda}$', 1200, 2500)
dislin.disfin ()


