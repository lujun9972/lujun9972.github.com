import re
import operator
from typing import Annotated, List, Literal
from langchain.tools import tool
from langgraph.prebuilt import ToolNode, InjectedState
from langchain.messages import AnyMessage, HumanMessage, SystemMessage
from typing_extensions import TypedDict

# ---------- 1. 工具 ----------
@tool
def get_inventory(state: Annotated[dict, InjectedState]):
    """Get current user inventory"""
    return state["inventory"]

@tool
def get_dietary_prefs(state: Annotated[dict, InjectedState]):
    """Get user dietary preferences"""
    return state["dietary_prefs"]

# 注意：没有 get_remaining_calories_range 工具
# Planner 只管做菜，热量约束是 Verifier 的事，Planner 不知道也不应该知道
planner_tools = [get_inventory, get_dietary_prefs]
model_with_planner_tools = llm.bind_tools(planner_tools)

# ---------- 2. 状态 ----------
class RecipeState(TypedDict):
    inventory: List[str]
    dietary_prefs: List[str]
    total_calories: int
    consumed_calories: int
    error_margin_calories: int
    messages: Annotated[List[AnyMessage], operator.add]

# ---------- 3. Planner 节点 ----------
def planner_node(state: RecipeState):
    messages_to_send = [
        SystemMessage(content=(
            "You are a chef. Suggest a recipe based on inventory and dietary prefs. "
            "IMPORTANT: You MUST provide an estimated calorie count for the meal "
            "(write it as ~数字 kcal, e.g. '~350 kcal'). "
            "Do NOT worry about calories — just be a good chef."
        ))
    ] + state["messages"]
    response = model_with_planner_tools.invoke(messages_to_send)
    return {"messages": [response]}

# ---------- 4. Verify 节点 ----------
def verify_node(state: RecipeState):
    last_message = state["messages"][-1].content
    remaining = state["total_calories"] - state["consumed_calories"]
    lo = remaining - state["error_margin_calories"]
    hi = remaining + state["error_margin_calories"]

    # 从食谱文本中提取卡路里数值（匹配 ~数字 kcal 或 约数字 kcal）
    cal_nums = [int(n) for n in re.findall(r'[~约](\d+)\s*(?:kc|千|大)', last_message, re.I)]
    estimated = cal_nums[-1] if cal_nums else 0  # 取最后一个数值（通常是总计）

    result = f"Recipe: ~{estimated} kcal. Budget: [{lo}, {hi}] kcal."
    if lo <= estimated <= hi:
        result += " VALID"
    else:
        result += f" INVALID ({estimated} is outside [{lo}, {hi}])"
    return {"messages": [HumanMessage(content=result)]}

# ---------- 5. 路由函数 ----------
tool_node = ToolNode(planner_tools)

def should_verify(state: RecipeState) -> Literal["tool_node", "verify_node", "__end__"]:
    last_message = state["messages"][-1]
    if last_message.tool_calls:
        return "tool_node"
    return "verify_node"

def is_it_valid(state: RecipeState) -> Literal["planner_node", "__end__"]:
    last_message = state["messages"][-1].content
    if "VALID" in last_message.upper() and "INVALID" not in last_message.upper():
        return "__end__"
    return "planner_node"

# ---------- 6. 构建图 ----------
from langgraph.graph import StateGraph, START, END

agent_builder = StateGraph(RecipeState)
agent_builder.add_node("planner_node", planner_node)
agent_builder.add_node("tool_node", tool_node)
agent_builder.add_node("verify_node", verify_node)
agent_builder.add_edge(START, "planner_node")
agent_builder.add_conditional_edges(
    "planner_node", should_verify,
    {"tool_node": "tool_node", "verify_node": "verify_node", END: END},
)
agent_builder.add_edge("tool_node", "planner_node")
agent_builder.add_conditional_edges(
    "verify_node", is_it_valid,
    {"planner_node": "planner_node", END: END},
)
agent = agent_builder.compile()

# ---------- 7. 执行 ----------
messages = [HumanMessage(content="推荐一个菜")]
current_inventory = ["豆腐", "牛肉末", "豆瓣酱", "葱", "花椒", "米饭"]
current_dietary_prefs = []

result = agent.invoke({
    "inventory": current_inventory,
    "dietary_prefs": current_dietary_prefs,
    "total_calories": 1000,
    "consumed_calories": 800,
    "error_margin_calories": 100,
    "messages": messages,
})
for m in result["messages"]:
    m.pretty_print()
