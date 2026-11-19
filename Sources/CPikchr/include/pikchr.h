/*
** Public interface of the vendored Pikchr renderer (https://pikchr.org).
** Pikchr is in the public domain; pikchr.c is copied unmodified from the
** SQLite documentation sources (sqlite-docsrc/search/pikchr.c).
*/
#ifndef CPIKCHR_H
#define CPIKCHR_H

#define PIKCHR_PLAINTEXT_ERRORS 0x0001
#define PIKCHR_DARK_MODE        0x0002

/* Render Pikchr source text to SVG. The result is obtained from malloc() and
** must be released with free(). On error, *pnWidth is set to -1 and the
** result holds an error message instead of SVG. */
char *pikchr(const char *zText, const char *zClass, unsigned int mFlags,
             int *pnWidth, int *pnHeight);

/* Version string of the vendored Pikchr. */
const char *pikchr_version(void);

#endif
