#!/usr/bin/pike
/* -*- Mode: pike; tab-width: 4; indent-tabs-mode: t; c-basic-offset: 4 -*- */

// Generate a table for sentencebreak classes.
#define USE_UNICODE_SEGMENTATION
#include "../unicode.h"

// Map from SentenceBreakProperty class name to our enum name and check that
// it is defined in unicode.h
string get_sbt(string sbt)
{
	sbt -= " ";
	if (sbt != "Other" && !this["SB_"+sbt])
		werror("*** ERROR ***: Unknown class: "+sbt+"\n");
	return "SB_"+sbt;
}

void main()
{
	// Sentencebreaking data
	array(array) table = ({});
	string sbt = "\0"*65536;

	// Read SentenceBreakProperty.txt
	foreach(Stdio.stdin.line_iterator(); int lno; string line) 
	{
		// Strip comments and split into semi-colon separated fields
		array(string) info = String.trim_all_whites((line/"#")[0])/";";
		if (sizeof(info) != 2)
			continue;

		// Fetch codepoints, either single or range
		int c1, c2;
		string sentencebreak = get_sbt(info[1]);
		string original_sentencebreak_class = sentencebreak;

		if (sscanf(info[0], "%x..%x", c1, c2) == 2)
		{
			// Range
		} 
		else 
		{
			// Single codepoint
			c2=c1;
		}

		// Store information
		for (int c = c1; c<=c2; c++) 
		{
			// Ignore non-BMP characters
			if (c > 65535)
				continue;

			// Remember for selftest
			sbt[c] = this[original_sentencebreak_class];

			// Store in run-length encoded table
			if (sizeof(table) && sentencebreak == table[-1][1] &&
			    table[-1][0] + table[-1][2] == c)
			{
				// Continue previous range
				table[-1][2]++;
			}
			else// if (this[linebreak_class])
			{
				// Create a new range
				table += ({ ({ c, sentencebreak, 1 }) });
			}
		}
	}

	// Sort
	table = sort(table);

	// Range-optimize the table "table" by joining adjacent intervals.
	array nt = ({table[0]});
	for (int i = 1; i < sizeof(table); i ++)
	{
		if (table[i][1] == nt[-1][1] && table[i][0] == nt[-1][0] + nt[-1][2])
			nt[-1][2] = (table[i][0]+table[i][2])-nt[-1][0];
		else
			nt += ({ table[i] });
	}
	table = nt;

	// Write selftest data
	Stdio.write_file("sbt.dat", sbt);

	// Write output
	write(#"/** @file sentencebreak.inl
 * This file is auto-generated by modules/unicode/scripts/make_sentencebreak.pike.
 * DO NOT EDIT THIS FILE MANUALLY.
 */\n
#ifdef USE_UNICODE_INC_DATA\n");

	// Write indices for wordbreak info and create the data table
	write("static const uni_char sentence_break_chars[] = {");
	int last_end = 0, ent, lbl;
	string data = "", tbl = "";
	foreach (table, array t)
	{
		if (last_end != t[0])
		{
			if (ent)
			{
				data += ", ";
				tbl  += ", ";
			}
			if (!(ent & 7))
			{
				data += "\n\t";
				tbl  += "\n\t";
			}
			ent ++;

			tbl += sprintf("0x%04x", last_end);
			data += "SB_Other";
		}

		if (ent)
		{
			data += ", ";
			tbl  += ", ";
		}
		if (!(ent & 7))
		{
			data += "\n\t";
			tbl  += "\n\t";
		}
		ent ++;

		tbl += sprintf("0x%04x", t[0]);
		last_end = t[0]+t[2];
		data += t[1];
	}

	// Sentinel
	if (table[-1][1] != 0)
	{
		tbl += sprintf(", 0x%04x", table[-1][0] + table[-1][2]);
		data += ", SB_Other";
	}

	write(tbl + "\n};\n#endif // USE_UNICODE_INC_DATA\n");

	// Write the data table
	write("static const char sentence_break_data[] = {" + data + "\n};\n");

	werror("%O/%O entries\n", ent, sizeof(table));
}