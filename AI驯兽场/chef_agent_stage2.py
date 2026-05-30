import operator
from typing import Annotated, List, Literal
from langchain.tools import tool
from langgraph.prebuilt import ToolNode, InjectedState
from langchain.messages import AnyMessage, SystemMessage
from typing_extensions import TypedDict

# ---------- 1. 定义工具 ----------
@tool
def get_inventory(state: Annotated[dict, InjectedState]):
    """Get current user inventory"""
    return state["inventory"]

@tool
def get_dietary_prefs(state: Annotated[dict, InjectedState]):
    """Get user dietary preferences"""
    return state["dietary_prefs"]

tools = [get_inventory, get_dietary_prefs]
model_with_tools = llm.bind_tools(tools)

# ---------- 2. 定义状态 ----------
class RecipeState(TypedDict):
    inventory: List[str]
    dietary_prefs: List[str]
    messages: Annotated[List[AnyMessage], operator.add]

# ---------- 3. LLM 节点 ----------
def llm_call(state: dict):
    messages_to_send = [
        SystemMessage(
            content="You are a helpful chef agent. When user asks for a recipe, "
                    "look at user's current inventory and dietary preferences to "
                    "suggest the recipe. You can use the available tools whenever needed."
        )
    ] + state["messages"]
    response = model_with_tools.invoke(messages_to_send)
    return {"messages": [response]}

# ---------- 4. 工具节点 ----------
tool_node = ToolNode(tools)

# ---------- 5. 条件边 ----------
def should_continue(state: RecipeState) -> Literal["tool_node", "__end__"]:
    messages = state["messages"]
    last_message = messages[-1]
    if last_message.tool_calls:
        return "tool_node"
    return "__end__"

# ---------- 6. 构建图 ----------
from langgraph.graph import StateGraph, START, END

agent_builder = StateGraph(RecipeState)
agent_builder.add_node("llm_call", llm_call)
agent_builder.add_node("tool_node", tool_node)
agent_builder.add_edge(START, "llm_call")
agent_builder.add_conditional_edges("llm_call", should_continue, ["tool_node", END])
agent_builder.add_edge("tool_node", "llm_call")
agent = agent_builder.compile()

# ---------- 7. 执行 ----------
from langchain.messages import HumanMessage

messages = [HumanMessage(content="推荐一个菜")]
current_inventory = ["豆腐", "牛肉末", "豆瓣酱", "葱", "花椒", "米饭"]
current_dietary_prefs = []

result = agent.invoke({
    "inventory": current_inventory,
    "dietary_prefs": current_dietary_prefs,
    "messages": messages,
})
for m in result["messages"]:
    m.pretty_print()
