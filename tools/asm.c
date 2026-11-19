#include <stdio.h>    // printf, fopen, fgets
#include <stdlib.h>   // strtol
#include <string.h>   // strchr, strcmp, strlen, strcpy
#include <ctype.h>    // isspace, isalpha, isalnum

// Reminder: s is a pointer (an address); *s is the character it points to
// Cleans one assembly line: removes the comment and surrounding whitespace
char *clean_line(char *s) {

    // 1. Cut the comment
    char *semi = strchr(s, ';');   // pointer to the ';', or NULL if there is none
    if (semi != NULL) {
        *semi = '\0';
    }

    // 2. Trim the end
    int n = strlen(s); // how many characters are left

    //  is the last one whitespace?
    while (n > 0 && isspace((unsigned char)s[n-1]))
    {
        s[n-1] = '\0';
        n--;
    }

    // 3. Skip the start
    while(isspace((unsigned char)*s)){
        s++;
    }
    return s;
}

// Splits a cleaned line into label, mnemonic and operand.
//   text     : cleaned line from clean_line (not empty)
//   mnemonic : filled with the first word after the label, or "" if none
//   operand  : filled with the second word, or "" if none
// Returns    : pointer to the label (without ':'), or "" if there is none
char *parse_line(char *text, char *mnemonic, char *operand) {
    char *label = "";       // default: no label
    mnemonic[0] = '\0';     // default: no mnemonic
    operand[0]  = '\0';     // default: no operand

    // 1. Label: everything before ':'
    char *colon = strchr(text, ':');                 // find the ':' (NULL if no label)
    if (colon != NULL) {
        *colon = '\0';                               // end the label at the ':'
        label = text;                                // label = text before the ':'
        text = colon + 1;                            // continue after the ':'
        while (isspace((unsigned char)*text)) {      // skip spaces before the mnemonic
            text++;
        }
    }

    // 2. Mnemonic and operand: up to two words in what is left
    if (text[0] != '\0') { // label-only lines have nothing left
        sscanf(text, "%15s %31s", mnemonic, operand); // first word -> mnemonic, second -> operand
    }

    return label;
}

// Converts operand text ("0x81", "129", "0b10000001") to a number.
// Returns 1 on success (value stored in *out), 0 if the text is not a valid 0..255 number.
int parse_number(const char *s, int *out) {
    char *end;
    const char *start = s;               // where the digits begin
    long value;

    if (s[0] == '0' && (s[1] == 'b' || s[1] == 'B')) {
        start = s + 2;                   // skip "0b"
        value = strtol(start, &end, 2);  // base 2: only 0 and 1 allowed
    } else {
        value = strtol(start, &end, 0);  // base 0: 0x.. hex or decimal
    }

    // Error handling
    if (end == start) return 0;              // no digits ("0b" alone, "loop")
    if (*end != '\0') return 0;              // junk after the number ("0b102", "0x1G")
    if (value < 0 || value > 255) return 0;  // operand is only 8 bits

    *out = (int)value;
    return 1;
}

// One row of the instruction table: mnemonic and its 4-bit opcode.
typedef struct {
    const char *name;
    int opcode;
} Op;

// Instructions that take an 8-bit operand (address or immediate).
// NOT, SKIP, CTL (NOP/HALT) and CLR (CLRA/CLRF) are handled separately in encode().
static const Op OPS[] = {
    {"ADD",  0x0}, {"SUB",  0x1}, {"AND",  0x2}, {"OR",   0x3},   // memory operand
    {"ADDI", 0x4}, {"SUBI", 0x5}, {"ANDI", 0x6}, {"ORI",  0x7},   // immediate operand
    {"LD",   0x8}, {"STE",  0x9}, {"LDI",  0xA}, {"GOTO", 0xB},
};

static const int NUM_OPS = sizeof OPS / sizeof OPS[0];         // 12 entries

// Returns the opcode for name (case-insensitive), or -1 if unknown.
int find_opcode(const char *name) {
    for (int i = 0; i < NUM_OPS; i++) {
        if (_stricmp(name, OPS[i].name) == 0) {   // 0 means equal, ignoring case
            return OPS[i].opcode;
        }
    }
    return -1;                                    // not in the table
}

// One label: its name and the ROM address it marks.
typedef struct {
    char name[32];
    int address;
} Symbol;

static Symbol symbols[256];     // at most one label per ROM address is plenty
static int num_symbols = 0;

// Returns the address of a label, or -1 if it is not defined.
int find_symbol(const char *name) {
    for (int i = 0; i < num_symbols; i++) {
        if (strcmp(symbols[i].name, name) == 0) {   // labels are case-sensitive
            return symbols[i].address;
        }
    }
    return -1;
}

// Checks a label name: starts with a letter or '_', then letters, digits or '_'.
int valid_label(const char *name) {
    if (!(isalpha((unsigned char)name[0]) || name[0] == '_')) return 0;
    for (int i = 1; name[i] != '\0'; i++) {
        if (!(isalnum((unsigned char)name[i]) || name[i] == '_')) return 0;
    }
    return strlen(name) < sizeof symbols[0].name;   // must fit in the table
}

// Records a label at an address. Returns 1 on success, 0 on error (reason printed).
int add_symbol(const char *name, int address, int lineno) {
    if (!valid_label(name)) {
        fprintf(stderr, "line %d: bad label name '%s'\n", lineno, name);
        return 0;
    }
    if (find_symbol(name) >= 0) {
        fprintf(stderr, "line %d: label '%s' is already defined\n", lineno, name);
        return 0;
    }
    if (num_symbols >= 256) {
        fprintf(stderr, "line %d: too many labels\n", lineno);
        return 0;
    }
    strcpy(symbols[num_symbols].name, name);       // safe: valid_label checked the length
    symbols[num_symbols].address = address;
    num_symbols++;
    return 1;
}

// Builds the 12-bit instruction word for one line.
// Returns the word (0x000..0xFFF), or -1 on error (reason printed to stderr).
int encode(const char *mnemonic, const char *operand, int lineno) {
    // Special forms: fixed words, no operand
    if (_stricmp(mnemonic, "NOP")  == 0) return 0xE00;   // CTL 0
    if (_stricmp(mnemonic, "HALT") == 0) return 0xE01;   // CTL 1
    if (_stricmp(mnemonic, "CLRA") == 0) return 0xF00;   // CLR 0: clear ACC
    if (_stricmp(mnemonic, "CLRF") == 0) return 0xF01;   // CLR 1: clear flags
    if (_stricmp(mnemonic, "NOT")  == 0) return 0xD00;   // operand ignored

    // SKIP: operand is a condition, operand[0] = flag (0 Z, 1 C), operand[1] = value
    if (_stricmp(mnemonic, "SKIP") == 0) {
        if (_stricmp(operand, "Z=0") == 0) return 0xC00;
        if (_stricmp(operand, "C=0") == 0) return 0xC01;
        if (_stricmp(operand, "Z=1") == 0) return 0xC02;
        if (_stricmp(operand, "C=1") == 0) return 0xC03;
        fprintf(stderr, "line %d: SKIP needs Z=0, Z=1, C=0 or C=1, got '%s'\n", lineno, operand);
        return -1;
    }

    // Normal instructions: opcode from the table, 8-bit operand
    int opcode = find_opcode(mnemonic);
    if (opcode < 0) {
        fprintf(stderr, "line %d: unknown instruction '%s'\n", lineno, mnemonic);
        return -1;
    }
    if (operand[0] == '\0') {
        fprintf(stderr, "line %d: %s needs an operand\n", lineno, mnemonic);
        return -1;
    }
    int value;
    if (!parse_number(operand, &value)) {
        value = find_symbol(operand);                     // not a number: try a label
        if (value < 0) {
            fprintf(stderr, "line %d: bad operand '%s' (not 0..255 or a defined label)\n",
                    lineno, operand);
            return -1;
        }
    }

    return (opcode << 8) | value;                         // [11:8] opcode, [7:0] operand
}

int main(int argc, char *argv[]) {
    // argc = number of words in the command line
    // argv = each word: argv[1] = input .asm, argv[2] = output .hex

    // Error 1: missing file names
    if (argc < 3) {
        fprintf(stderr, "Usage: asm <input.asm> <output.hex>\n");
        return 1;
    }

    // Open the input file
    FILE *in = fopen(argv[1], "r");
    if (in == NULL) {
        fprintf(stderr, "cannot open '%s'\n", argv[1]);
        return 1;
    }

    // Open the output file
    FILE *out = fopen(argv[2], "w");
    if (out == NULL) {
        fprintf(stderr, "cannot open '%s' for writing\n", argv[2]);
        fclose(in);
        return 1;
    }

    char line[256];
    char *text;
    int address = 0;    // ROM address of the next instruction (also the word count)
    int errors  = 0;    // number of problems found

    // Pass 1: record every label and its address (nothing is written)
    // Pass 2: encode every instruction (labels are now all known)
    for (int pass = 1; pass <= 2; pass++) {
        rewind(in);                                      // back to the start of the file
        int lineno = 0;                                  // source line number, for error messages
        address = 0;

        while (fgets(line, sizeof line, in) != NULL) {
            char mnemonic[16];
            char operand[32];

            lineno++;
            text = clean_line(line);
            if (text[0] == '\0') continue;               // blank or comment-only line

            char *label = parse_line(text, mnemonic, operand);

            if (pass == 1 && label[0] != '\0') {         // label marks the next instruction
                if (!add_symbol(label, address, lineno)) errors++;
            }

            if (mnemonic[0] == '\0') continue;           // label-only line: no instruction

            if (address > 255) {                         // ROM holds 256 instructions
                if (pass == 1) {
                    fprintf(stderr, "line %d: program too long (max 256 instructions)\n", lineno);
                    errors++;
                }
                break;
            }

            if (pass == 2) {
                int word = encode(mnemonic, operand, lineno);
                if (word < 0) {
                    errors++;                            // encode already printed why
                } else {
                    fprintf(out, "%03X // %s%s%s\n", word, mnemonic,
                            operand[0] ? " " : "", operand);   // no trailing space without operand
                }
            }
            address++;                                   // every instruction takes one address
        }

        if (errors > 0) break;                           // don't encode if pass 1 failed
    }

    fclose(in);
    fclose(out);

    if (errors > 0) {
        fprintf(stderr, "%d error(s), %s is incomplete\n", errors, argv[2]);
        return 1;
    }
    printf("assembled %d words into %s\n", address, argv[2]);
    return 0;
}
