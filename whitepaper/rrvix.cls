% rrvix.cls -- rrvix paper class v0.1
%
% Provides a LaTeX class for rrvix submissions. Extends `article` with
% semantic environments that the rrvix parser extracts into the Canonical
% Intermediate Representation (CIR) without requiring post-hoc OCR.
%
% Status: v0.1, dogfooded by the rrvix whitepaper itself.
%
% License: MIT.

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{rrvix}[2026/05/04 v0.1 rrvix paper class]

% Pass options to article
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass[11pt]{article}

% ---- Required packages ----
\RequirePackage[a4paper, margin=1in]{geometry}
\RequirePackage[utf8]{inputenc}
\RequirePackage[T1]{fontenc}
\RequirePackage{amsmath, amsthm, amssymb, mathtools}
\RequirePackage{graphicx}
\RequirePackage{xcolor}
\RequirePackage{enumitem}
\RequirePackage[numbers]{natbib}
\RequirePackage{booktabs}
\RequirePackage{authblk}
\RequirePackage[colorlinks=true,
                linkcolor=blue!50!black,
                citecolor=blue!50!black,
                urlcolor=blue!50!black]{hyperref}

% ---- rrvix metadata commands ----
% These are extracted by the rrvix parser into CIR top-level fields.
\newcommand{\rrvixid}[1]{\def\@rrvixid{#1}}
\newcommand{\rrvixversion}[1]{\def\@rrvixversion{#1}}
\newcommand{\rrvixprotocolversion}[1]{\def\@rrvixprotocolversion{#1}}
\newcommand{\rrvixlicense}[1]{\def\@rrvixlicense{#1}}
\newcommand{\rrvixtopics}[1]{\def\@rrvixtopics{#1}}

% Defaults
\rrvixid{TBD}
\rrvixversion{v1}
\rrvixprotocolversion{0.1.0}
\rrvixlicense{CC-BY-4.0}
\rrvixtopics{}

% ---- Sidecar log channel ----
% The rrvix parser reads structured metadata from a `.rrvix.aux` channel
% emitted via \write. This lets us extract claim content without re-parsing
% TeX after the fact. The sidecar uses a simple line-based format:
% RRVIX:<kind>:<label>:<json-escaped-content>
%
% v0.1: emit on \begin{...} and \end{...} for tracked environments.
% v0.2: capture content body. For now the parser falls back to source scan.
\newwrite\rrvix@sidecar
\AtBeginDocument{%
  \immediate\openout\rrvix@sidecar=\jobname.rrvix.aux\relax
  \immediate\write\rrvix@sidecar{RRVIX:meta:id:\@rrvixid}%
  \immediate\write\rrvix@sidecar{RRVIX:meta:version:\@rrvixversion}%
  \immediate\write\rrvix@sidecar{RRVIX:meta:protocol:\@rrvixprotocolversion}%
  \immediate\write\rrvix@sidecar{RRVIX:meta:license:\@rrvixlicense}%
  \immediate\write\rrvix@sidecar{RRVIX:meta:topics:\@rrvixtopics}%
}
\AtEndDocument{\immediate\closeout\rrvix@sidecar}

\newcommand{\rrvix@emit}[2]{%
  \immediate\write\rrvix@sidecar{RRVIX:#1:\@currentlabel}%
}

% ---- Theorem-like environments (visual style) ----
\theoremstyle{definition}
\newtheorem{rrvix@claim}{Claim}
\newtheorem{rrvix@evidence}{Evidence}
\newtheorem{rrvix@observation}{Observation}
\newtheorem{rrvix@remark}{Remark}
\newtheorem{rrvix@scope}{Scope}
\newtheorem{rrvix@openquestion}{Open Question}

% ---- Public semantic environments ----
% Each takes an optional title. Each emits a sidecar marker on \begin so the
% parser can locate it in the source. Claims, in particular, get a stable
% local label that the CIR uses for the claim ID (paper_id:label).

\newenvironment{claim}[1][]{%
  \begin{rrvix@claim}[#1]%
  \rrvix@emit{claim}{begin}%
}{%
  \end{rrvix@claim}%
}

\newenvironment{evidence}[1][]{%
  \begin{rrvix@evidence}[#1]%
  \rrvix@emit{evidence}{begin}%
}{%
  \end{rrvix@evidence}%
}

\newenvironment{observation}[1][]{%
  \begin{rrvix@observation}[#1]%
  \rrvix@emit{observation}{begin}%
}{%
  \end{rrvix@observation}%
}

\newenvironment{rrvixremark}[1][]{%
  \begin{rrvix@remark}[#1]%
  \rrvix@emit{remark}{begin}%
}{%
  \end{rrvix@remark}%
}

\newenvironment{scope}[1][]{%
  \begin{rrvix@scope}[#1]%
  \rrvix@emit{scope}{begin}%
}{%
  \end{rrvix@scope}%
}

\newenvironment{openquestion}[1][]{%
  \begin{rrvix@openquestion}[#1]%
  \rrvix@emit{openquestion}{begin}%
}{%
  \end{rrvix@openquestion}%
}

% ---- Inline edge declarations ----
% These declare typed edges between claims without producing visual output.
% They emit sidecar markers only.

\newcommand{\dependson}[2]{\immediate\write\rrvix@sidecar{RRVIX:edge:depends_on:#1:#2}}
\newcommand{\contradicts}[2]{\immediate\write\rrvix@sidecar{RRVIX:edge:contradicts:#1:#2}}
\newcommand{\extendsclaim}[2]{\immediate\write\rrvix@sidecar{RRVIX:edge:extends:#1:#2}}
\newcommand{\supports}[2]{\immediate\write\rrvix@sidecar{RRVIX:edge:supports:#1:#2}}

% ---- Convenience macros consistent with common math notation ----
\newcommand{\R}{\mathbb{R}}
\newcommand{\N}{\mathbb{N}}
\newcommand{\Z}{\mathbb{Z}}
\newcommand{\E}{\mathbb{E}}
\newcommand{\Prob}{\mathbb{P}}
\newcommand{\1}{\mathbf{1}}

% ---- Done ----
\endinput
