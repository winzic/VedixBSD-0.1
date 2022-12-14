/*
  (c) copyright 1988 by the Vrije Universiteit, Amsterdam, The Netherlands.
  See the copyright notice in the ACK home directory, in the file "Copyright".
*/

/*
  Module:	initialization and some global vars
  Author:	Ceriel J.H. Jacobs
  Version:	$Header: /cvsup/minix/src/lib/ack/libm2/init.c,v 1.1 2005/10/10 15:27:46 beng Exp $
*/

#include <signal.h>
#include <em_abs.h>
#include <m2_traps.h>

/* map unix signals onto EM traps */
init()
{
	sigtrp(M2_UNIXSIG, SIGHUP);
	sigtrp(M2_UNIXSIG, SIGINT);
	sigtrp(M2_UNIXSIG, SIGQUIT);
	sigtrp(EILLINS, SIGILL);
	sigtrp(M2_UNIXSIG, SIGTRAP);
	sigtrp(M2_UNIXSIG, SIGIOT);
	sigtrp(M2_UNIXSIG, SIGEMT);
	sigtrp(M2_UNIXSIG, SIGFPE);
	sigtrp(M2_UNIXSIG, SIGBUS);
	sigtrp(M2_UNIXSIG, SIGSEGV);
#ifdef SIGSYS
	sigtrp(EBADMON, SIGSYS);
#endif
	sigtrp(M2_UNIXSIG, SIGPIPE);
	sigtrp(M2_UNIXSIG, SIGALRM);
	sigtrp(M2_UNIXSIG, SIGTERM);
}

killbss()
{
	/* Fill bss with junk?  Make lots of VM pages dirty?  No way! */
}

extern int catch();

int (*handler)() = catch;
char **argv;
int argc;
char *MainLB;
