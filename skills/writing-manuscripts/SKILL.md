---
name: writing-manuscripts
disable-model-invocation: true
description: This skill is a "style guide" for contributing to publication-quality manuscripts
---

- Prose cannot be rigidly prescribed: items below should be treated as general
  guidelines rather than rules, and any of them can be violated when justified
  by the circumstances.

- My own writing style was shaped by several influences. One of these is public
  and should be considered explicitly when structuring your prose: Gopen &
  Swan's "The Science of Scientific Writing" (American Scientist, 1990). Do not
  search for it; the summary here is sufficient.

  Their central claim: readers have structural expectations about where kinds
  of information appear in a sentence. When prose violates those expectations,
  readers spend energy decoding structure that should have gone to content.
  Every unit of discourse should serve a single function or make a single
  point. Their principles:

  1. Follow a grammatical subject as soon as possible with its verb.
  2. Place in the stress position (the point of syntactic closure, usually the
     end of the sentence) the new information you want the reader to emphasize.
  3. Place the person or thing whose story the sentence is telling at the
     beginning, in the topic position.
  4. Place old information (material already stated) in the topic position, for
     linkage backward and context forward.
  5. Articulate the action of every clause or sentence in its verb.
  6. Provide context for your reader before asking the reader to consider
     anything new.
  7. Ensure that the relative emphases of the substance coincide with the
     relative expectations for emphasis raised by the structure.

  These are expectations, not rules: skilled writers violate them to good
  effect, but only because they fulfill them most of the time.

- Reader attention is finite and effortful, and directing it is one of the
  writer's main jobs. Before asking readers to follow a long or detailed
  passage, tell them what is at stake, what distinguishes this problem or
  solution from nearby ones, and why the obvious approaches fall short. This
  both motivates readers to continue and gives them a framework for
  interpreting each technical detail when it arrives. Rigor and systematic
  results remain essential, but they are usually more impactful after the intuition
  is in place. Simon Peyton Jones's "How to Write a Great Research Paper"
  makes this same case: once readers have the intuition they can follow the
  details, but not the reverse. In some cases, a brief illustration, concrete
  example, illuminating counterfactual, or analogy can help build that intuition.

  A reader who stops after the opening paragraph should be able to say
  what the section will settle, why it is not trivially settled, and what the
  answer will hinge on. A rhetorical question with no stakes attached may not
  meet this standard.

  An opening is not a table of contents. Give the stakes and the few key terms
  the reader should watch for; leave out roadmaps of every subsection and terms
  that are defined later. An opening that previews all the details asks the
  reader to absorb concepts not yet introduced, and blurs the few that matter.
  
  How much of this framing is appropriate may depend on the content, journal,
  and audience.

- Prefer plain prose, avoiding invented jargon or non-traditional metaphors.
  Jargon is acceptable and encouraged when it is standard within the field of
  anticipated readers. Manuscripts should not have the flavor of a pitch deck
  or inappropriately use financial or tech-bro lingo. While humans sometimes
  personify objects or concepts, agents often take this too far: for example,
  in most cases it's better to say that an algorithm depends on its inputs,
  not that it *reads* its inputs.

- When reporting results, use the appropriate tense: mathematical results *are*
  true, but experiments *were* performed in lab, on particular benchmarks, or on
  machines with specific roundoff characteristics. The more a result depends on
  arbitrary choices or factors that might not be exactly reproducible for all
  readers or in all circumstances, the greater the incentive to report in
  past-tense.

- Avoid the temptation to describe every result, particularly numerical ones,
  in prose: figures or tables are generally the preferred format for most
  quantitative data. In an analysis I did of an agent-generated draft of
  a results section for a numerical analysis manuscript, agents had dumped
  about eight times as many numbers into the results section compared to the
  median of 16 peer-reviewed manuscripts written without agentic assistance.
  A number belongs in the prose only if it materially supports what the reader
  should take away from the subsection. 

- Experiments should not exist merely to confirm a theorem ("Theorem 3.2
  checks out"); that is the job of proofs and package tests. Experiments earn
  their place by addressing what the theory cannot settle: how many iterations
  convergence takes in practice, how tight a bound is, how a method behaves on
  inputs outside a theorem's hypotheses.

- In single-author manuscripts, avoid the "authorial we." Other forms of "we"
  (author-reader, community, etc.) are acceptable.

- If drafting LaTeX, don't wrap at fixed width. If the goal is to limit the size
  of future diffs, use breaks between sentences instead.
 
- Do not mix analysis or writing code with writing prose: experience shows that
  when those two are mixed in the same session, prose quality falls off a cliff.
  Writing clear, human readable prose is difficult for agents and deserves full
  attention.
