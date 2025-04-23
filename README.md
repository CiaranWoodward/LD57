# A Game Dev Experiment: Ludum Dare 57 with AI

## The Experiment

This project was an experimental game development approach for Ludum Dare 57, where CiaranWoodward explored using agentic AI tools (like me!) for nearly the entire development process. Unlike typical game jams where code is carefully crafted by hand, this project was almost entirely "vibe coded" - allowing AI to generate code based on high-level descriptions and iterative feedback.

## The Process

As the AI assistant, I helped generate:
- The core game architecture
- Isometric tile-based systems
- Entity management
- Turn-based gameplay mechanics
- Even this README itself!

The development happened through conversation rather than traditional programming. CiaranWoodward would describe features or systems, and I would generate complete implementations, often with minimal human modification.

## The Results

The experiment produced a functional isometric strategy game foundation with:
- Custom isometric grid system (avoiding Godot's built-in TileMaps)
- Entity-tile interactions
- Basic pathfinding
- Game state management
- Input handling systems

## Reflections

CiaranWoodward found the experiment intriguing and enlightening. The AI tools proved incredibly powerful for rapid prototyping and generating functional code quickly. However, the experience revealed important limitations:

The resulting codebase became:
- Extremely disorganized
- Difficult to maintain by hand
- Filled with countless bugs
- Challenging to extend through traditional programming

Perhaps most significantly, this approach made time management exceptionally difficult. Without a clear gauge of implementation complexity, CiaranWoodward completely missed the jam deadline by several weeks - an unprecedented occurrence in his game jam experience. The unpredictable nature of AI-generated code and the iterative troubleshooting process made it nearly impossible to accurately estimate development timelines.

## Lessons Learned

While AI coding tools offer remarkable capabilities for generating working code rapidly, they work best when used more conservatively and strategically. The "vibe coding" approach produced interesting results but created technical debt that would be challenging to address in a longer-term project.

## Special Thanks

CiaranWoodward would like to extend sincere gratitude to his extremely patient collaborators who endured this experimental process. Their support and understanding made this unusual approach to game development possible.

## Future Directions

For future projects, CiaranWoodward plans to use AI coding tools more judiciously - leveraging their strengths for specific tasks while maintaining more direct control over the codebase's overall architecture and organization. 