/*
 * (c) copyright 1987 by the Vrije Universiteit, Amsterdam, The Netherlands.
 * See the copyright notice in the ACK home directory, in the file "Copyright".
 */
/* $Header: /cvsup/minix/src/lib/ansi/abs.c,v 1.1.1.1 2005/04/21 14:56:04 beng Exp $ */

#include	<stdlib.h>

int
abs(register int i)
{
	return i >= 0 ? i : -i;
}
