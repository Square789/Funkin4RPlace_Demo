-- script by CoolingTool to fix boundary mania preview being broken cause of the riser 
-- being removed from the song audio into the countdown

-- this script uses the custom lua binary luvit, go to https://luvit.io/ to install it

local json = require("json");
local fs = require("fs");

local FILE = "boundary-mania-broken.json";
local OUT = "../../assets/preload/data/boundary/boundary-mania.json";
local SHIFT_AMOUNT_BY_BEATS = -2;

local chart = json.decode(fs.readFileSync(FILE));
local bpm = chart.song.bpm;
local crochet = (60 / bpm) * 1000;
local stepCrochet = crochet / 4;
local offset = crochet * SHIFT_AMOUNT_BY_BEATS;
local modifedNotes = {};

local function reversedipairsiter(t, i)
    i = i - 1
    if i ~= 0 then
        return i, t[i]
    end
end

function reversedipairs(t)
    return reversedipairsiter, t, #t + 1
end

local currentPosition = 0
for _, section in pairs(chart.song.notes) do -- this loops only purpose is to get the songs length
	currentPosition = currentPosition + section.lengthInSteps * stepCrochet;
end

for i, section in reversedipairs(chart.song.notes) do
	currentPosition = currentPosition - section.lengthInSteps * stepCrochet;
	for j, note in reversedipairs(section.sectionNotes) do
		if not modifedNotes[note] then
			note[1] = note[1] + offset;
			modifedNotes[note] = true;
		end
			
		if note[1] < currentPosition then
			-- shift note back one section
			local lastSection = chart.song.notes[i-1];
			if lastSection then
				if section.mustHitSection ~= lastSection.mustHitSection then
					local swap = -4;
					if note[2] < 4 then
						swap = 4;
					end
					note[2] = note[2] + swap;
				end
			
				lastSectionNotes = lastSection.sectionNotes;
				lastSectionNotes[#lastSectionNotes+1] = note;
			end
			table.remove(section.sectionNotes, j);
		end
	end
end

fs.writeFileSync(OUT, json.encode(chart, {indent = true}));
