from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

reflex_prompt = ChatPromptTemplate.from_template(
    "You are a chef. Given a request: {input}, provide a single recipe immediately."
)
reflex_agent = reflex_prompt | llm | StrOutputParser()

print(reflex_agent.invoke({"input": "我想吃辣的"}))
