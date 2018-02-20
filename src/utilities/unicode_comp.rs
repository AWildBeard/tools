/*
 * Program: unicode_comp.rs
 * Author: Michael Mitchell
 * Description: This program spits out the UTF-8 escape characters that can be used
 *              to create the character or phrase that can be passed to it via 
 *              the command line or during runtime. This program was created as a
 *              utility to analyze the Apple జ్ఞ problem. This program makes a best
 *              effort attempt to perfectly preserve the input.
 */

fn main() {
    let mut buf = String::new();
    let has_command_args;

    {
        let args = std::env::args();

        if args.len() > 1 {
            has_command_args = true;
            for arg in args.skip(1) {
                buf.push_str(&arg);
                buf.push(' '); // Spaces are dropped by env::args()
            }
        } else { has_command_args = false; }
    }

    if ! has_command_args {
        use std::io::{stdout, stdin, Write};

        let mut stdout = stdout();
        let stdin = stdin();

        print!("Enter a character or phrase: ");
        stdout.flush().expect("The sky is falling!");
        stdin.read_line(&mut buf).expect("Failed to read input!");
    }

    for character in buf.trim().chars() {
        print!("U+{:04X}\n", character as u16);
    }

}
