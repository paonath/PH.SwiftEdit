# Example Mapping & The Three Amigos Discovery Process

Created by Matt Wynne (SmartBear), Example Mapping is a 25-minute collaborative workshop.

## 1. The 4 Colored Cards

1. **Yellow Card (User Story)**: The feature or story under discussion.
2. **Blue Card (Business Rule)**: A business acceptance policy or constraint. Maps directly to `Rule:` in Gherkin.
3. **Green Card (Example)**: A concrete illustration of the rule. Maps to `Scenario:` or `Scenario Outline:` in Gherkin.
4. **Red Card (Question)**: An unanswered uncertainty or assumption. Prevents blocking discussion during the session.

## 2. Example Mapping Rules of Thumb
- If a story has more than 4–5 Blue Cards (Rules), it is too large: split the story.
- If a Blue Card (Rule) has no Green Cards (Examples), it is abstract and untested: brainstorm examples.
- If too many Red Cards (Questions) accumulate, the story is not ready for implementation: conduct technical or domain spikes.
