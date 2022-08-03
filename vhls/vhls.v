module vhls

import os
import time
import net.http
import net.urllib
import phoreverpheebs.m3u8

const agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36'

pub fn download_playlist(playlist_url string, output string) ? {
	mut purl := urllib.parse(playlist_url) or { panic('Initial url parse failed: $err') } // playlist + url = purl, dw about it

	for {
		mut config := http.FetchConfig{
			url: playlist_url
			user_agent: agent
			method: .get
		}

		mut resp := http.fetch(config) or {
			eprintln('Error on playlist URL request: $err')
			time.sleep(2 * time.second)
			continue
		}

		playlist := m3u8.decode(resp.body, false)?

		if playlist is m3u8.MasterPlaylist {
			mut media_playlist_url := ''
			eprintln('Got master playlist, selecting the last variant')

			for i := playlist.variants.len-1; i > 0; i-- {
				if playlist.variants[i].uri != '' {
					media_playlist_url = playlist.variants[i].uri
					break
				}
			} 

			if !media_playlist_url.starts_with('http') {
				media_playlist_url = change_url_base(purl.str(), media_playlist_url)?.str()
			}
			
			return download_playlist(media_playlist_url, output)

		} else if playlist is m3u8.MediaPlaylist {
			mut file := os.create(output) or { panic(err) }
			eprintln('Creating output file...')

			mut downloaded_segments := map[string]bool{}

			for _, segment in playlist.segments {
				if segment.uri != '' {
					mut media_uri := ''

					if segment.uri.starts_with('http') {
						media_uri = urllib.query_unescape(segment.uri)?
					} else {
						media_url := change_url_base(purl.str(), segment.uri) or {
							eprintln('parsing relative path to url failed: $err')
							continue
						}
						media_uri = urllib.query_unescape(media_url.str())?
					}

					if downloaded_segments[media_uri] {
						continue
					}

					eprint('Downloading segment: $segment.uri')

					config = http.FetchConfig{
						url: media_uri
						user_agent: agent
						method: .get
					}

					resp = http.fetch(config) or {
						eprintln(err)
						continue
					}

					if resp.status() != .ok {
						eprintln('Got ${resp.status()} from $media_uri')
						continue
					}

					written := file.write_string(resp.body) or { panic(err) }

					if written > 0 {
						downloaded_segments[media_uri] = true
						eprintln('\tDownloaded!')
					} else {
						eprintln('\nNo data written from: $segment.uri')
					}
				}
			}

			file.close()

			if playlist.closed {
				return
			}
		} else {
			eprintln('Invalid playlist type')
			return
		}
	}
}

fn change_url_base(raw_url string, new_path string) ?urllib.URL {
	mut url := urllib.parse(raw_url)?
	mut path := url.path.split('/')
	path[path.len-1] = new_path

	url.path = path.join('/')

	return url
}