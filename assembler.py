import sys

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} FILENAME [-1]")
    sys.exit(1)
first_error_only = (len(sys.argv) > 2 and sys.argv[2] == "-1")

try:
    with open(sys.argv[1]) as file:
        content = file.readlines()
except FileNotFoundError:
    print(f"Couldn't open a file {sys.argv[1]}")
    sys.exit(2)

BINARY_SIZE = 16

compilation_error_num = 0
binary = [0] * BINARY_SIZE
binary_ptr = 0

def compilation_error(line, line_num, message):
    global compilation_error_num
    print(f"Compilation error at line {line_num}: '{line}'\n  {message}")
    if first_error_only:
        sys.exit(3)
    compilation_error_num += 1

for line_num, line in enumerate(content):
    comment_start_index = line.find(';')
    if comment_start_index != -1:
        line = line[:comment_start_index]

    line = line.strip().lower()

    instruction_end_index = line.find(' ')
    if instruction_end_index != -1:
        instruction = line[:instruction_end_index]
        args = line[instruction_end_index:]
        args = [arg.strip() for arg in args.split(',')]
    else:
        instruction = line
        args = []

    if instruction == "noop":
        binary[binary_ptr] = 0x00

    elif instruction == "ld":
        if args[0] == "a":
            binary[binary_ptr] = 0x10
        elif args[0] == "b":
            binary[binary_ptr] = 0x11
        else:
            compilation_error(line, line_num, f"Invalid first argument '{args[0]}' for instruction '{instruction}'")

    elif instruction == "st":
        if args[0] == "a":
            binary[binary_ptr] = 0x20
        elif args[0] == "b":
            binary[binary_ptr] = 0x21
        else:
            compilation_error(line, line_num, f"Invalid first argument '{args[0]}' for instruction '{instruction}'")

    elif instruction == "ldd":
        if args[0] == "a":
            binary[binary_ptr] = 0x30
        elif args[0] == "b":
            binary[binary_ptr] = 0x31
        else:
            compilation_error(line, line_num, f"Invalid first argument '{args[0]}' for instruction '{instruction}'")
        binary_ptr += 1

        try:
            value = int(args[1], base=0)
        except ValueError:
            compilation_error(line, line_num, f"Invalid second argument '{args[1]}' for instruction '{instruction}'. Should be a number")
            continue

        binary[binary_ptr] = value

    elif instruction == "jz":
        binary[binary_ptr] = 0xe0

    elif instruction == "halt":
        binary[binary_ptr] = 0xf0

    else:
        compilation_error(line, line_num, f"Unknown instruction '{instruction}'")

    binary_ptr += 1

if compilation_error_num > 0:
    print(f"Compilation failed with {compilation_error_num} error(s)")
    sys.exit(3)

converter = lambda x: format(x, "02x")
with open("initram.hex", "w") as file:
    file.write("\n".join(map(converter, binary)))

print("Compilation completed successfully")
