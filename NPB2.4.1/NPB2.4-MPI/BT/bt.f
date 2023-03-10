!-------------------------------------------------------------------------!
!                                                                         !
!        N  A  S     P A R A L L E L     B E N C H M A R K S  2.4         !
!                                                                         !
!                                   B T                                   !
!                                                                         !
!-------------------------------------------------------------------------!
!                                                                         !
!    This benchmark is part of the NAS Parallel Benchmark 2.4 suite.      !
!    It is described in NAS Technical Reports 95-020 and 02-007.          !
!                                                                         !
!    Permission to use, copy, distribute and modify this software         !
!    for any purpose with or without fee is hereby granted.  We           !
!    request, however, that all derived work reference the NAS            !
!    Parallel Benchmarks 2.4. This software is provided "as is"           !
!    without express or implied warranty.                                 !
!                                                                         !
!    Information on NPB 2.4, including the technical report, the          !
!    original specifications, source code, results and information        !
!    on how to submit new results, is available at:                       !
!                                                                         !
!           http://www.nas.nasa.gov/Software/NPB/                         !
!                                                                         !
!    Send comments or suggestions to  npb@nas.nasa.gov                    !
!                                                                         !
!          NAS Parallel Benchmarks Group                                  !
!          NASA Ames Research Center                                      !
!          Mail Stop: T27A-1                                              !
!          Moffett Field, CA   94035-1000                                 !
!                                                                         !
!          E-mail:  npb@nas.nasa.gov                                      !
!          Fax:     (650) 604-3957                                        !
!                                                                         !
!-------------------------------------------------------------------------!

c---------------------------------------------------------------------
c
c Authors: R. F. Van der Wijngaart
c          T. Harris
c          M. Yarrow
c
c---------------------------------------------------------------------

c---------------------------------------------------------------------
       program MPBT
c---------------------------------------------------------------------

       include  'header.h'
       include  'mpinpb.h'
      
       integer i, niter, step, c, error, fstatus, n3
       double precision navg, mflops

       external timer_read
       double precision t, tmax, timer_read
       logical verified
       character class

       integer wr_interval

       call setup_mpi
       if (.not. active) goto 999

c---------------------------------------------------------------------
c      Root node reads input file (if it exists) else takes
c      defaults from parameters
c---------------------------------------------------------------------
       if (node .eq. root) then
          
          write(*, 1000)
          open (unit=2,file='inputbt.data',status='old', iostat=fstatus)
c
          if (fstatus .eq. 0) then
            write(*,233) 
 233        format(' Reading from input file inputbt.data')
            read (2,*) niter
            read (2,*) dt
            read (2,*) grid_points(1), grid_points(2), grid_points(3)
            if (iotype .ne. 0) then
                read (2,*) wr_interval
            endif
            if (iotype .eq. 1) then
                read (2,*) collbuf_nodes, collbuf_size
                print *, "collbuf_nodes ", collbuf_nodes
                print *, "collbuf_size ", collbuf_size
            endif
            close(2)
          else
            write(*,234) 
            niter = niter_default
            dt    = dt_default
            grid_points(1) = problem_size
            grid_points(2) = problem_size
            grid_points(3) = problem_size
            wr_interval = wr_default
            if (iotype .eq. 1) then
c             set number of nodes involved in collective buffering to 4,
c             unless total number of nodes is smaller than that.
c             set buffer size for collective buffering to 1MB per node
              collbuf_nodes = min(4,no_nodes)
              collbuf_size = 1 000 000
            endif
          endif
 234      format(' No input file inputbt.data. Using compiled defaults')

          write(*, 1001) grid_points(1), grid_points(2), grid_points(3)
          write(*, 1002) niter, dt
          if (no_nodes .ne. total_nodes) write(*, 1004) total_nodes
          if (no_nodes .ne. maxcells*maxcells) 
     >        write(*, 1005) maxcells*maxcells
          write(*, 1003) no_nodes

          if (iotype .eq. 1) write(*, 1006) 'FULL MPI-IO', wr_interval
          if (iotype .eq. 2) write(*, 1006) 'SIMPLE MPI-IO', wr_interval
          if (iotype .eq. 3) write(*, 1006) 'EPIO', wr_interval
          if (iotype .eq. 4) write(*, 1006) 'FORTRAN IO', wr_interval

 1000 format(//, ' NAS Parallel Benchmarks 2.4 -- BT Benchmark ',/)
 1001     format(' Size: ', i3, 'x', i3, 'x', i3)
 1002     format(' Iterations: ', i3, '    dt: ', F10.6)
 1004     format(' Total number of processes: ', i5)
 1005     format(' WARNING: compiled for ', i5, ' processes ')
 1003     format(' Number of active processes: ', i5, /)
 1006     format(' BTIO -- ', A, ' write interval: ', i2 /)

       endif

       call mpi_bcast(niter, 1, MPI_INTEGER,
     >                root, comm_setup, error)

       call mpi_bcast(dt, 1, dp_type, 
     >                root, comm_setup, error)

       call mpi_bcast(grid_points(1), 3, MPI_INTEGER, 
     >                root, comm_setup, error)

       call mpi_bcast(wr_interval, 1, MPI_INTEGER,
     >                root, comm_setup, error)

       call make_set

       do  c = 1, maxcells
          if ( (cell_size(1,c) .gt. IMAX) .or.
     >         (cell_size(2,c) .gt. JMAX) .or.
     >         (cell_size(3,c) .gt. KMAX) ) then
             print *,node, c, (cell_size(i,c),i=1,3)
             print *,' Problem size too big for compiled array sizes'
             goto 999
          endif
       end do

       call set_constants

       call initialize

       call setup_btio
       idump = 0

       call lhsinit

       call exact_rhs

       call compute_buffer_size(5)

c---------------------------------------------------------------------
c      do one time step to touch all code, and reinitialize
c---------------------------------------------------------------------
       call adi
       call initialize

c---------------------------------------------------------------------
c      Synchronize before placing time stamp
c---------------------------------------------------------------------
       call mpi_barrier(comm_setup, error)

       call timer_clear(1)
       call timer_start(1)

       do  step = 1, niter

          if (node .eq. root) then
             if (mod(step, 20) .eq. 0 .or. step .eq. niter .or.
     >           step .eq. 1) then
                write(*, 200) step
 200            format(' Time step ', i4)
             endif
          endif

          call adi

          if (iotype .ne. 0) then
              if (mod(step, wr_interval).eq.0 .or. step .eq. niter) then
                  if (node .eq. root) then
                      print *, 'Writing data set, time step', step
                  endif
                  call output_timestep
                  idump = idump + 1
              endif
          endif
       end do

       call btio_cleanup

       call timer_stop(1)
       t = timer_read(1)
       
       call verify(niter, class, verified)

       call mpi_reduce(t, tmax, 1, 
     >                 dp_type, MPI_MAX, 
     >                 root, comm_setup, error)

       if( node .eq. root ) then
          n3 = grid_points(1)*grid_points(2)*grid_points(3)
          navg = (grid_points(1)+grid_points(2)+grid_points(3))/3.0
          if( tmax .ne. 0. ) then
             mflops = 1.0e-6*float(niter)*
     >     (3478.8*float(n3)-17655.7*navg**2+28023.7*navg)
     >     / tmax
          else
             mflops = 0.0
          endif
         call print_results('BT', class, grid_points(1), 
     >     grid_points(2), grid_points(3), niter, maxcells*maxcells, 
     >     total_nodes, tmax, mflops, '          floating point', 
     >     verified, npbversion,compiletime, cs1, cs2, cs3, cs4, cs5, 
     >     cs6, '(none)')
       endif

 999   continue
       call mpi_barrier(MPI_COMM_WORLD, error)
       call mpi_finalize(error)

       end

