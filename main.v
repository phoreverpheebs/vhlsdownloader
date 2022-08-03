import os
import vhls

fn main() {
	if os.args.len < 3 {
		eprintln('Usage: vhlsdownloader <playlist-url> <output-filename>')
		exit(1)
	}

	vhls.download_playlist(os.args[1], os.args[2]) or { panic('download failed: $err') }
}