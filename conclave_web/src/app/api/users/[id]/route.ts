import { clerkClient } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(
    _req: Request,
    context: { params: Promise<{ id: string }> }
) {
    try {
        const { id } = await context.params;
        const client = await clerkClient();
        const user = await client.users.getUser(id);
        const fullName =
            user.fullName ||
            [user.firstName, user.lastName].filter(Boolean).join(" ") ||
            user.username ||
            null;

        return Response.json({
            id: user.id,
            username: user.username,
            firstName: user.firstName,
            lastName: user.lastName,
            fullName,
            imageUrl: user.imageUrl,
        });
    } catch (err) {
        return new Response(JSON.stringify({ error: "User not found" }), {
            status: 404,
            headers: { "content-type": "application/json" },
        });
    }
}


