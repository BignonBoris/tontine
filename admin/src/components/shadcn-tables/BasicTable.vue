<script setup lang="ts">
import { basicTableData1 } from "@/_mockApis/tables/tablesData";
import { Table, TableHeader, TableRow, TableHead, TableBody, TableCell } from "@/components/ui/table/index";
import Badge from "@/components/ui/badge/Badge.vue";
import { Avatar, AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import Card from "@/components/ui/card/Card.vue";
</script>

<template>
    <Card class="border shadow-none p-0">
        <Table>
            <TableHeader>
                <TableRow class="hover:bg-transparent">
                    <TableHead>Users</TableHead>
                    <TableHead>Project Name</TableHead>
                    <TableHead>Team</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Budget</TableHead>
                </TableRow>
            </TableHeader>

            <TableBody>
                <TableRow v-for="item in basicTableData1" :key="item.name" class="hover:bg-transparent">
                    <!-- User -->
                    <TableCell>
                        <div class="flex gap-3 items-center">
                            <Avatar class="h-10 w-10 ">
                                <AvatarImage :src="item.avatar" alt="avatar" />
                                <AvatarFallback>{{ item.name.charAt(0) }}</AvatarFallback>
                            </Avatar>
                            <div>
                                <h5 class="whitespace-nowrap text-base">
                                    {{ item.name }}
                                </h5>
                                <p class="text-sm  whitespace-nowrap text-muted">
                                    {{ item.post }}
                                </p>
                            </div>
                        </div>
                    </TableCell>

                    <!-- Project Name -->
                    <TableCell>
                        <h6 class="text-base whitespace-nowrap">
                            {{ item.pname }}
                        </h6>
                    </TableCell>

                    <!-- Team -->
                    <TableCell>
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
                    </TableCell>

                    <!-- Status -->
                    <TableCell>
                        <Badge class="font-semibold text-xs px-2 py-0.5"
                            :class="`bg-light${item.statuscolor} text-${item.statuscolor}`">
                            {{ item.status }}
                        </Badge>
                    </TableCell>

                    <!-- Budget -->
                    <TableCell>
                        <h6 class="text-base">{{ item.budget }}</h6>
                    </TableCell>
                </TableRow>
            </TableBody>
        </Table>
    </Card>
</template>
