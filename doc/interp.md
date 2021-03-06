# Notes About Interpolation

## Definitions

Round parenthesis, as in `f(t)`, denote a continuous function (`t` is a real
number), square brakets, as in `a[k]`, denote a sampled function (`k`is an
integer number).

Interpolation amounts to convolving with a kernel `h(t)`:

    dest(t) = sum_k src[clip(k)]*h(t - k)

where `clip(k)` imposes the boundary conditions and makes sure that the
resulting index is within bounds.

It can be seen tat interpolation acts as a linear filter.  Finite impulse
response (FIR) filters have a finite support.  By convention we use centered
kernels, thus the support is `(-s,+s)`.  Infinite impulse response (IIR)
filters have an infinite support.


## Support and Bounds

Computation of bounds (remember that `t` is floating point, while `k` is integer):

    floor(t) ≤ k   <=>   t < k+1
    floor(t) < k   <=>   t < k

    floor(t) ≥ k   <=>   t ≥ k
    floor(t) > k   <=>   t ≥ k+1

Let `s` denotes the half-width of the support of the kernel.  We assume that
the support size is strict, i.e. `h(+/-s) = 0`.  Thus, for a given `t`, the
indexes `k` to take into account are such that:

    |t - k| < s   <=>   t - s < k < t + s

We now assume that `w = 2*s`, the width of the kernel support, is integer.  If
`w` is even, then `s` is integer and (without clipping) the list of neighbors
is:

    k = k0 - s + 1, ..., k0 - 1, k0, k0 + 1, ..., k0 + s

with `k0 = floor(t)`.  For kernels with an odd full-width support, `s = j +
1/2` with `j = s - 1/2` an integer and (again without clipping) the list of
neighbors to consider is:

    k = k0 - j, ..., k0 - 1, k0, k0 + 1, ..., k0 + j

with `k0 = floor(t + 1/2) = lround(t)` the index of the nearest neighbor of
position `t`.

This shows that the first index to take into account (before clipping) is:

    k1 = floor(t) - s + 1
       = floor(t - (s - 1))           for `w = 2*s` even

    k1 = floor(t + 1/2) - j
       = floor(t - (j - 1/2))
       = floor(t - (s - 1))           for `w = 2*s` odd

Thus whatever the parity of the kernel support size, the first index to take
into account (before clipping) is:

    k1 = floor(t - toff)    with    toff = s - 1

and all indexes to consider are:

    k = k1, k1 + 1, ..., k1 + 2*s - 1

The last index is also given by:

    k1 + 2*s - 1 = floor(t + s)

Thus all indexes are in the following bounds:

    floor(t - s + 1) ≤ k ≤ floor(t + s)


## Clipping

Now we have the constraint that: `kmin ≤ k ≤ kmax`.  If we apply a *"nearest
bound"* condition, then:

* if `k1 + 2*s - 1 ≤ kmin`, then **all** `k` are clipped to `kmin`; this occurs
  whenever:
  ```
  floor(t - s + 1) + 2*s - 1 ≤ kmin   <=>   t < kmin - s + 1
  ```

* if `kmax ≤ k1`, then **all** `k` are clipped to `kmax`; this occurs whenever:
  ```
  floor(t - s + 1) ≥ kmax   <=>   t ≥ kmax + s - 1
  ```

These cases have to be considered before computing `k1 = (int)floor(t - s + 1)`
not only for optimization reasons but also because `floor(...)` may be beyond
the limits of a numerical integer.

The most simple case in when all considered indexes are within the bounds which
implies:

    kmin ≤ k1   and   k1 + 2*s - 1 ≤ kmax
    <=>   kmin + s - 1 ≤ t < kmax - s + 1


## Cubic Interpolation

Keys's cubic interpolation kernels are given by:

    h(t) = (a+2)*|t|^3 - (a+3)*|t|^2 + 1          for |t| ≤ 1
         = a*|t|^3 - 5*a*|t|^2 + 8*a*|t| - 4*a    for 1 < |t| < 2
         = 0                                      else

Mitchell and Netravali family of piecewise cubic filters (depends on 2
parameters: `b` and `c`) are given by:

    h(t) = (1/6)*((12 - 9*b - 6*c)*|t|^3
            + (-18 + 12*b + 6*c)*|t|^2 + (6 - 2*B))       for |t| ≤ 1
         = (1/6)*((-b - 6*c)*|t|^3 + (6*b + 30*c)*|t|^2
           + (-12*b - 48*c)*|t| + (8*b + 24*c))           for 1 < |t| < 2
         = 0                                              else

These kernels are continuous, symmetric, have continuous 1st derivatives and
sum of coefficients is one (needs not be normalized).  Using the constraint:

    b + 2*c = 1

yields a cubic filter with, at least, quadratic order approximation.

    (b,c) = (1,0)     ==> cubic B-spline
    (b,c) = (0, -a)   ==> Keys's cardinal cubics
    (b,c) = (0,1/2)   ==> Catmull-Rom cubics
    (b,c) = (b,0)     ==> Duff's tensioned B-spline
    (b,c) = (1/3,1/3) ==> recommended by Mitchell-Netravali

See paper by Mitchell and Netravali, "Reconstruction Filters in Computer
Graphics Computer Graphics", Volume 22, Number 4, August 1988
http://www.cs.utexas.edu/users/fussell/courses/cs384g/lectures/mitchell/Mitchell.pdf.


## Resampling

Resampling/interpolation is done by:

    dst[i] = sum_j ker(grd[j] - pos[i])*src[j]

with `dst` the resulting array, `src` the values of a function sampled on a
regular grid `grd`, `ker` the interpolation kernel, and `pos` the coordinates
where to interpolate the sampled function.

To limit the storage and the number of operations, we want to determine the
range of indexes for which the kernel function is non-zero.  We have that:

    abs(t) ≥ s/2  ==>  ker(t) = 0

with `s = length(ker)`.  Taking `t = grd[j] - pos[i]`, then:

    abs(t) < s/2  <==>  pos[i] - s/2 < grd[j] < pos[i] + s/2

`grd` is a `Range` so an "exact" formula for its elements is given by a linear
interpolation:

    grd[j] = t0*(j1 - j)/(j1 - j0) + t1*(j - j0)/(j1 - j0)

with:

    j0 = 1             # first grid index
    j1 = length(grd)   # last grid index
    t0 = first(grd)    # first grid coordinate
    t1 = last(grd)     # last grid coordinate

Note that:

    d = (t1 - t0)/(j1 - j0)
      = step(grd)

is the increment between adjacent grip nodes (may be negative).

The reverse formula in the form of a linear interpolation is:

    f[i] = j0*(t1 - pos[i])/(t1 - t0) + j1*(pos[i] - t0)/(t1 - t0)

which yields a (fractional) grid index `f` for coordinate `pos[i]`.  Taking
care of the fact that the grid step may be negative, the maximum number of
non-zero coefficients is given by:

    M = floor(Int, length(ker)/abs(step(grd)))
      = floor(Int, w)

with:

    w = length(ker)/abs(d)    # beware d = step(grd) may be negative

the size of the support in grid index units.  The indexes of the first non-zero
coefficients are:

    j = l[i] + k

for `k = 1, 2, ..., M` and

    l[i] = ceil(Int, f[i] - w/2) - 1

the corresponding offsets are (assuming the grid extends infinitely):

    t[i,j] = pos[i] - grd[j]
           = pos[i] - (grd[0] + (l[i] + k)*d)
           = ((pos[i] - grd[0])/d - l[i] - k)*d
           = (f[i] - l[i] - k)*d

The final issue to address is to avoid `InexactError` exceptions.
