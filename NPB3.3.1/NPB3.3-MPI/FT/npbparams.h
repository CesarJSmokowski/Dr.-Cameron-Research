c NPROCS = 1 CLASS = A
c  
c  
c  This file is generated automatically by the setparams utility.
c  It sets the number of processors and the class of the NPB
c  in this directory. Do not modify it by hand.
c  
        integer nx, ny, nz, maxdim, niter_default, ntdivnp, np_min
        parameter (nx=256, ny=256, nz=128, maxdim=256)
        parameter (niter_default=6)
        parameter (np_min = 1)
        parameter (ntdivnp=((nx*ny)/np_min)*nz)
        double precision ntotal_f
        parameter (ntotal_f=1.d0*nx*ny*nz)
        logical  convertdouble
        parameter (convertdouble = .false.)
        character*11 compiletime
        parameter (compiletime='19 Feb 2023')
        character*5 npbversion
        parameter (npbversion='3.3.1')
        character*3 cs1
        parameter (cs1='f77')
        character*9 cs2
        parameter (cs2='$(MPIF77)')
        character*22 cs3
        parameter (cs3='-L/usr/local/lib -lmpi')
        character*20 cs4
        parameter (cs4='-I/usr/local/include')
        character*28 cs5
        parameter (cs5='-O3 -fopenmp -mcmodel=medium')
        character*28 cs6
        parameter (cs6='-O3 -fopenmp -mcmodel=medium')
        character*6 cs7
        parameter (cs7='randi8')
