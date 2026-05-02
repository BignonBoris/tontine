<script setup lang="ts">
import { basicTableData1 } from "@/_mockApis/tables/tablesData";
import { Table, TableHeader, TableRow, TableHead, TableBody, TableCell } from "@/components/ui/table/index";
import { Badge } from "@/components/ui/badge";


import { Card } from "@/components/ui/card/index";
import Avatar from "../ui/avatar/Avatar.vue";
import AvatarImage from "../ui/avatar/AvatarImage.vue";
import AvatarFallback from "../ui/avatar/AvatarFallback.vue";

</script>

<template>
    <Card class="border shadow-none p-0">
        <Table>
            <TableHeader>
                <TableRow class="hover:bg-transparent">
                    <TableHead class="text-base font-semibold whitespace-nowrap px-5 py-3 text-start">Users</TableHead>
                    <TableHead class="text-base font-semibold whitespace-nowrap px-5 py-3 text-start">Project Name
                    </TableHead>
                    <TableHead class="text-base font-semibold whitespace-nowrap px-5 py-3 text-start">Team</TableHead>
                    <TableHead class="text-base font-semibold whitespace-nowrap px-5 py-3 text-start">Status</TableHead>
                    <TableHead class="text-base font-semibold whitespace-nowrap px-5 py-3 text-start">Budget</TableHead>
                </TableRow>
            </TableHeader>

            <TableBody>
                <TableRow v-for="item in basicTableData1" :key="item.name" class="hover:bg-muted/10">
                    <!-- Users -->
                    <TableCell>
                        <div class="flex items-center gap-3">
                            <Avatar class="h-10 w-10">
                                <AvatarImage :src="item.avatar" alt="avatar" />
                                <AvatarFallback>{{ item.name.charAt(0) }}</AvatarFallback>
                            </Avatar>
                            <div>
                                <h5 class="font-semibold text-15">{{ item.name }}</h5>
                                <div class="text-sm text-muted">{{ item.post }}</div>
                            </div>
                        </div>
                    </TableCell>

                    <!-- Project Name -->
                    <TableCell>
                        <div class="font-medium text-muted-foreground">
                            {{ item.pname }}
                        </div>
                    </TableCell>

                    <!-- Team -->
                    <TableCell>
                        <div class="flex -space-x-2">
                            <div class="flex items-center">
                                <div class="flex -space-x-2">
                                    <Avatar v-for="team in item.teams" :key="team.id"
                                        class="h-9 w-9 border-2 border-background bg-gray-200"
                                        :class="`bg-${team.color} text-white`">
                                        <AvatarFallback :class="`bg-${team.color} `">{{
                                            team.text
                                            }}</AvatarFallback>
                                    </Avatar>
                                </div>
                            </div>
                        </div>
                    </TableCell>

                    <!-- Status -->
                    <TableCell class="px-5 py-3">
                        <Badge class="rounded-md font-semibold text-xs px-2 py-0.5"
                            :class="`bg-light${item.statuscolor} text-${item.statuscolor}`">
                            {{ item.status }}
                        </Badge>
                    </TableCell>

                    <!-- Budget -->
                    <TableCell class="px-5 py-3">
                        <div class="font-semibold text-foreground">{{ item.budget }}</div>
                    </TableCell>
                </TableRow>
            </TableBody>
        </Table>
    </Card>
</template>
