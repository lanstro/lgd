# structural line types

ACT              = 0
CHAPTER          = 1
PART             = 2
DIVISION         = 3
SUBDIVISION      = 4
SECTION          = 5
SUBSECTION       = 6
PARAGRAPH        = 7
SUBPARAGRAPH     = 8
SUBSUBPARAGRAPH  = 9
PARA_LIST_HEAD   = 10
TEXT             = 11

# turns on various status messages in the console
DEBUG = true

DEFINITIONAL_FEATURE_STEMS = ["includ", "mean", "definit", "see"]

STRUCTURAL_FEATURE_WORDS = ["act", "chapter", "chapters", "part", "parts", "division", "divisions", "subdivision", "subdivisions",
	"section", "sections", "subsection", "subsections", "paragraph", "paragraphs", "subparagraph", "subparagraphs", "regulation",
	"regulations"]
	
STRUCTURAL_ALIASES = {

	ACT =>             ["Act"],
	CHAPTER =>         ["Chapter", "Ch", "Chap"],
	PART =>            ["Part", "Pt"],
	DIVISION =>        ["Division", "Div"],
	SUBDIVISION =>     ["Subdivision", "Sub division", "Subdiv", "Sub", "Sdiv"],
	SECTION =>         ["Section", "s", "Sec"],
	SUBSECTION =>      ["Subsection", "Sub", "Ss", "s", "para"],
	PARAGRAPH =>       ["Paragraph", "p", "para", "s"],
	SUBPARAGRAPH =>    ["Subparagraph", "Sub-paragraph", "subpara", "sub-para", "subp", "s", "para"],
	SUBSUBPARAGRAPH => ["Subsubparagraph", "Sub-subparagraph", "subpara", "subp", "subparagraph", "s", "para"],
	PARA_LIST_HEAD =>  ["Text"],
	TEXT =>            ["Text"]

}