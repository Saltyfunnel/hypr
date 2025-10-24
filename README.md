💩 Saltyfunnel's "Hypr" Garbage Dump (AKA: The Proof I Should Not Be Allowed Near a Keyboard)

Look, I Get It: You're Here For The Crap

I'm not going to lie to you. This entire repo is a monument to procrastination, a testament to how far you can get just by typing a vague request into a fancy chatbot and hoping for the best.

These are my Hyprland dotfiles, which are about as original as a "Live, Laugh, Love" sign. The configuration is basically a giant game of digital telephone: I saw a cool screenshot on Reddit, asked ChatGPT how to do it, and then pasted the result here without understanding half the lines.

If you’re looking for best practices, turn around. This repo is a fragile house of cards, full of commented-out weirdness and half-finished ideas I abandoned when the TV got interesting. It works, mostly, which is honestly the most depressing part.

🛠️ The Tech Stack (It's All Just Borrowed Stuff)

The only thing I actually built here was the file structure. Everything else is the heavy lifting of people smarter than me.

Hyprland: The window manager itself. It’s too good for me, honestly.

pywal16: The real MVP. This thing looks at my wallpaper and tells all my apps what colors to use. I didn't choose the color scheme; my wallpaper's dominant shades chose it for me. This is how I avoid making any actual decisions about aesthetics.

Waybar: Custom, I guess? I spent 45 minutes moving the clock from the left to the right and called it a day. It probably has a memory leak.

Tofi: A lightning-fast, highly efficient app launcher that I use, without fail, to open my terminal, which is the only app I ever use anyway. Complete overkill, but hey, it looks different.

The Install Script: Oh, yeah. That.

⚠️ The "Installation" (No Seriously, Don't)

Listen closely. If you run the steps below, you are willingly taking a script written by someone who asked an AI to write a config, and you're running it with elevated privileges on your own machine. I'm not a professional. I barely passed high school. I am warning you now: Look at the script before you run it.

But if you are determined to break things, here are the instructions:

   Get the Files (The least damaging step):
    
    git clone https://github.com/Saltyfunnel/hypr

   Give The Scripts Permission to Wreck Your Day:
  
    cd hypr
    chmod +x scripts/*.sh

  Run the Stupid Thing:

    cd scripts
    sudo sh install.sh

After running that sudo command, your computer is no longer my problem. Expect some packages to be missing, some configs to point to files that don't exist, and possibly a strange new keybind that just opens a picture of a cat.

🙏 Actual Credits (The People Who Deserve Your Attention)

ChatGPT: My unpaid, uncredited intern. You deserve all the stars.

The pywal16 Devs: You made me look like I know what I'm doing. Thank you.

Every Single Person on r/unixporn: I stole your ideas. All of them.

Me: I successfully typed the word sudo without immediately crashing my system. It's the small victories, you know?
